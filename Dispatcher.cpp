#include "Dispatcher.hpp"

// Includes
#include <stdexcept>
#include <iostream>
#include <thread>
#include <sstream>
#include <iomanip>
#include <random>
#include <thread>
#include <algorithm>
#include "hexadecimal.hpp"

static void printResult(const result r, const cl_uchar score, const std::chrono::time_point<std::chrono::steady_clock> & timeStart) {
	// Time delta
	const auto seconds = std::chrono::duration_cast<std::chrono::seconds>(std::chrono::steady_clock::now() - timeStart).count();

	// Format address
	const std::string strSalt = toHex(r.salt, 32);
	const std::string strPublic = toHex(r.hash, 20);

	// Print
	const std::string strVT100ClearLine = "\33[2K\r";
	std::cout << strVT100ClearLine << "  Time: " << std::setw(5) << seconds << "s Score: " << std::setw(2) << (int) score << " Salt: 0x" << strSalt << " Address: 0x" << strPublic << std::endl;
}

Dispatcher::OpenCLException::OpenCLException(const std::string s, const cl_int res) :
	std::runtime_error( s + " (res = " + lexical_cast::write(res) + ")"),
	m_res(res)
{

}

void Dispatcher::OpenCLException::OpenCLException::throwIfError(const std::string s, const cl_int res) {
	if (res != CL_SUCCESS) {
		throw OpenCLException(s, res);
	}
}

cl_command_queue Dispatcher::Device::createQueue(cl_context & clContext, cl_device_id & clDeviceId) {
	// nVidia CUDA Toolkit 10.1 only supports OpenCL 1.2 so we revert back to older functions for compatability
#ifdef ERADICATE2_DEBUG
	cl_command_queue_properties p = CL_QUEUE_PROFILING_ENABLE;
#else
	cl_command_queue_properties p = 0;
#endif

#ifdef CL_VERSION_2_0
	const cl_command_queue ret = clCreateCommandQueueWithProperties(clContext, clDeviceId, &p, NULL);
#else
	const cl_command_queue ret = clCreateCommandQueue(clContext, clDeviceId, p, NULL);
#endif
	return ret == NULL ? throw std::runtime_error("failed to create command queue") : ret;
}

cl_kernel Dispatcher::Device::createKernel(cl_program & clProgram, const std::string s) {
	cl_kernel ret  = clCreateKernel(clProgram, s.c_str(), NULL);
	return ret == NULL ? throw std::runtime_error("failed to create kernel \"" + s + "\"") : ret;
}

Dispatcher::Device::Device(Dispatcher & parent, cl_context & clContext, cl_program & clProgram, cl_device_id clDeviceId, const size_t worksizeLocal, const size_t size, const size_t index) :
	m_parent(parent),
	m_index(index),
	m_clDeviceId(clDeviceId),
	m_worksizeLocal(worksizeLocal),
	m_clScoreMax(0),
	m_clQueue(createQueue(clContext, clDeviceId) ),
	m_kernelIterate(createKernel(clProgram, "eradicate2_iterate")),
	m_memResult(clContext, m_clQueue, CL_MEM_READ_WRITE, ERADICATE2_MAX_SCORE + 1),
	m_memMode(clContext, m_clQueue, CL_MEM_READ_ONLY | CL_MEM_HOST_WRITE_ONLY, 1),
	m_round(0)
{

}

Dispatcher::Device::~Device() {

}

Dispatcher::Dispatcher(cl_context & clContext, cl_program & clProgram, const size_t worksizeMax, const size_t size)
	: m_clContext(clContext), m_clProgram(clProgram), m_worksizeMax(worksizeMax), m_size(size), m_clScoreMax(0), m_eventFinished(NULL), m_countPrint(0) {

}

Dispatcher::~Dispatcher() {

}

void Dispatcher::addDevice(cl_device_id clDeviceId, const size_t worksizeLocal, const size_t index) {
	Device * pDevice = new Device(*this, m_clContext, m_clProgram, clDeviceId, worksizeLocal, m_size, index);
	m_vDevices.push_back(pDevice);
}

void Dispatcher::run(const mode & mode) {
	m_eventFinished = clCreateUserEvent(m_clContext, NULL);
	timeStart = std::chrono::steady_clock::now();

	for (auto it = m_vDevices.begin(); it != m_vDevices.end(); ++it) {
		Device & d = **it;
		d.m_round = 0;

		for (size_t i = 0; i < ERADICATE2_MAX_SCORE + 1; ++i) {
			d.m_memResult[i].found = 0;
		}

		// Copy data
		*d.m_memMode = mode;
		d.m_memMode.write(true);
		d.m_memResult.write(true);

		// Kernel arguments - eradicate2_iterate
		d.m_memResult.setKernelArg(d.m_kernelIterate, 0);
		d.m_memMode.setKernelArg(d.m_kernelIterate, 1);
		CLMemory<cl_uchar>::setKernelArg(d.m_kernelIterate, 2, d.m_clScoreMax); // Updated in handleResult()		
		CLMemory<cl_uint>::setKernelArg(d.m_kernelIterate, 3, d.m_index);
		// Round information updated in deviceDispatch()
	}
	
	m_quit = false;
	m_countRunning = m_vDevices.size();

	std::cout << "Running..." << std::endl;
	std::cout << std::endl;

	// Start asynchronous dispatch loop on all devices
	for (auto it = m_vDevices.begin(); it != m_vDevices.end(); ++it) {
		deviceDispatch(*(*it));
	}

	// Wait for finish event
	clWaitForEvents(1, &m_eventFinished);
	clReleaseEvent(m_eventFinished);
	m_eventFinished = NULL;
}

void Dispatcher::enqueueKernel(cl_command_queue & clQueue, cl_kernel & clKernel, size_t worksizeGlobal, const size_t worksizeLocal, cl_event * pEvent = NULL) {
	const size_t worksizeMax = m_worksizeMax;
	size_t worksizeOffset = 0;
	while (worksizeGlobal) {
		const size_t worksizeRun = std::min(worksizeGlobal, worksizeMax);
		const size_t * const pWorksizeLocal = (worksizeLocal == 0 ? NULL : &worksizeLocal);
		const auto res = clEnqueueNDRangeKernel(clQueue, clKernel, 1, &worksizeOffset, &worksizeRun, pWorksizeLocal, 0, NULL, pEvent);
		OpenCLException::throwIfError("kernel queueing failed", res);

		worksizeGlobal -= worksizeRun;
		worksizeOffset += worksizeRun;
	}
}

void Dispatcher::enqueueKernelDevice(Device & d, cl_kernel & clKernel, size_t worksizeGlobal, cl_event * pEvent = NULL) {
	try {
		enqueueKernel(d.m_clQueue, clKernel, worksizeGlobal, d.m_worksizeLocal, pEvent);
	} catch ( OpenCLException & e ) {
		// If local work size is invalid, abandon it and let implementation decide
		if ((e.m_res == CL_INVALID_WORK_GROUP_SIZE || e.m_res == CL_INVALID_WORK_ITEM_SIZE) && d.m_worksizeLocal != 0) {
			std::cout << std::endl << "warning: local work size abandoned on GPU" << d.m_index << std::endl;
			d.m_worksizeLocal = 0;
			enqueueKernel(d.m_clQueue, clKernel, worksizeGlobal, d.m_worksizeLocal, pEvent);
		}
		else {
			throw;
		}
	}
}

void Dispatcher::deviceDispatch(Device & d) {
	// Check result
	for (auto i = ERADICATE2_MAX_SCORE; i > m_clScoreMax; --i) {
		result & r = d.m_memResult[i];

		if (r.found > 0 && i >= d.m_clScoreMax) {
			d.m_clScoreMax = i;
			CLMemory<cl_uchar>::setKernelArg(d.m_kernelIterate, 2, d.m_clScoreMax);

			std::lock_guard<std::mutex> lock(m_mutex);
			if (i >= m_clScoreMax) {
				m_clScoreMax = i;

				// TODO: Add quit condition

				printResult(r, i, timeStart);
			}

			break;
		}
	}

	d.m_parent.m_speed.update(d.m_parent.m_size, d.m_index);

	if (m_quit) {
		std::lock_guard<std::mutex> lock(m_mutex);
		if (--m_countRunning == 0) {
			clSetUserEventStatus(m_eventFinished, CL_COMPLETE);
		}
	} else {
		cl_event event;
		d.m_memResult.read(false, &event);
		
		CLMemory<cl_uint>::setKernelArg(d.m_kernelIterate, 4, ++d.m_round); // Round information updated in deviceDispatch()
		enqueueKernelDevice(d, d.m_kernelIterate, m_size);
		clFlush(d.m_clQueue);

		const auto res = clSetEventCallback(event, CL_COMPLETE, staticCallback, &d);
		OpenCLException::throwIfError("failed to set custom callback", res);
	}
}

void CL_CALLBACK Dispatcher::staticCallback(cl_event event, cl_int event_command_exec_status, void * user_data) {
	if (event_command_exec_status != CL_COMPLETE) {
		throw std::runtime_error("Dispatcher::onEvent - Got bad status" + lexical_cast::write(event_command_exec_status));
	}

	Device * const pDevice = static_cast<Device *>(user_data);
	pDevice->m_parent.deviceDispatch(*pDevice);
	clReleaseEvent(event);
}

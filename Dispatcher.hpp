#ifndef HPP_DISPATCHER
#define HPP_DISPATCHER

#include <stdexcept>
#include <fstream>
#include <string>
#include <vector>
#include <mutex>

#if defined(__APPLE__) || defined(__MACOSX)
#include <OpenCL/cl.h>
#define clCreateCommandQueueWithProperties clCreateCommandQueue
#else
#include <CL/cl.h>
#endif

#include "SpeedSample.hpp"
#include "CLMemory.hpp"
#include "types.hpp"

#define ERADICATE2_SPEEDSAMPLES 20
#define ERADICATE2_MAX_SCORE 40

class Dispatcher {
	private:
		class OpenCLException : public std::runtime_error {
			public:
				OpenCLException(const std::string s, const cl_int res);

				static void throwIfError(const std::string s, const cl_int res);

				const cl_int m_res;
		};

		struct Device {
			static cl_command_queue createQueue(cl_context & clContext, cl_device_id & clDeviceId);
			static cl_kernel createKernel(cl_program & clProgram, const std::string s);

			Device(Dispatcher & parent, cl_context & clContext, cl_program & clProgram, cl_device_id clDeviceId, const size_t worksizeLocal, const size_t size, const size_t index);
			~Device();

			Dispatcher & m_parent;
			const size_t m_index;

			cl_device_id m_clDeviceId;
			size_t m_worksizeLocal;
			cl_uchar m_clScoreMax;
			cl_command_queue m_clQueue;

			cl_kernel m_kernelInit;
			cl_kernel m_kernelIterate;

			CLMemory<ethhash> m_memHash;
			CLMemory<cl_uchar> m_memAddress;
			CLMemory<cl_uchar> m_memInitCodeDigest;
			CLMemory<cl_ulong4> m_memSalt;
			CLMemory<result> m_memResult;
			CLMemory<mode> m_memMode;

			// Speed sampling
			SpeedSample m_speed;
		};

	public:
		Dispatcher(cl_context & clContext, cl_program & clProgram, const size_t worksizeMax, const size_t size);
		~Dispatcher();

		void addDevice(cl_device_id clDeviceId, const size_t worksizeLocal, const size_t index);
		void run(const mode & mode, const std::string strAddress, const std::string strInitCodeDigest);

	private:
		void deviceInit(Device & d, const mode & mode, const std::string & strAddress, const std::string & strInitCode);
		void deviceDispatch(Device & d);

		void enqueueKernel(cl_command_queue & clQueue, cl_kernel & clKernel, size_t worksizeGlobal, const size_t worksizeLocal, cl_event * pEvent);
		void enqueueKernelDevice(Device & d, cl_kernel & clKernel, size_t worksizeGlobal, cl_event * pEvent);

		void printSpeed();

	private:
		static void CL_CALLBACK staticCallback(cl_event event, cl_int event_command_exec_status, void * user_data);

		static std::string formatSpeed(double s);

	private: /* Instance variables */
		cl_context & m_clContext;
		cl_program & m_clProgram;
		const size_t m_worksizeMax;
		const size_t m_size;
		cl_uchar m_clScoreMax;
		std::vector<Device *> m_vDevices;

		cl_event m_eventFinished;

		// Run information
		std::mutex m_mutex;
		std::chrono::time_point<std::chrono::steady_clock> timeStart;
		unsigned int m_countPrint;
		unsigned int m_countRunning;
		bool m_quit;
};

#endif /* HPP_DISPATCHER */

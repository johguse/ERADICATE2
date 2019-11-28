#include "Speed.hpp"

#include <functional>
#include <iostream>
#include <sstream>
#include <numeric>
#include <iomanip>

static std::string formatSpeed(double f) {
	const std::string S = " KMGT";

	unsigned int index = 0;
	while (f > 1000.0f && index < S.size()) {
		f /= 1000.0f;
		++index;
	}

	std::ostringstream ss;
	ss << std::fixed << std::setprecision(3) << (double)f << " " << S[index] << "H/s";
	return ss.str();
}

Speed::Speed(const unsigned int intervalPrintMs, const unsigned int intervalSampleMs) :
	m_intervalPrintMs(intervalPrintMs),
	m_intervalSampleMs(intervalSampleMs),
	m_lastPrint(0) {
}

Speed::~Speed() {
}

void Speed::update(const unsigned int numPoints, const unsigned int indexDevice) {
	std::lock_guard<std::recursive_mutex> lockGuard(m_mutex);

	const auto ns = std::chrono::steady_clock::now().time_since_epoch().count();
	const bool bPrint = ((ns - m_lastPrint) / 1000000) > m_intervalPrintMs;

	updateList(numPoints, ns, m_lSamples);
	updateList(numPoints, ns, m_mDeviceSamples[indexDevice]);

	if (bPrint) {
		m_lastPrint = ns;
		this->print();
	}
}

double Speed::getSpeed() const {
	return this->getSpeed(m_lSamples);
}

double Speed::getSpeed(const unsigned int indexDevice) const {
	return m_mDeviceSamples.count(indexDevice) == 0 ? 0 : this->getSpeed(m_mDeviceSamples.at(indexDevice));
}

double Speed::getSpeed(const sampleList & l) const {
	std::lock_guard<std::recursive_mutex> lockGuard(m_mutex);
	if (l.size() == 0) {
		return 0.0;
	}

	auto lambda = [&](double a, samplePair b) { return a + static_cast<double>(b.second); };

	const double timeDelta = static_cast<double>(l.back().first - l.front().first);
	const double numPointsSum = std::accumulate(l.begin(), l.end(), 0.0, lambda);

	return timeDelta == 0.0 ? 0.0 : numPointsSum / (timeDelta / 1000000000.0);
}

void Speed::updateList(const unsigned int & numPoints, const long long & ns, sampleList & l) {
	l.push_back(samplePair(ns, numPoints));

	// Pop old samples until time difference between first and last element is less than or equal to m_sampleSeconds
	// We don't need to check size of m_lSamples since it's always >= 1 at this point
	while (l.size() > 2 && (l.back().first - l.front().first) / 1000000 > m_intervalSampleMs) {
		l.pop_front();
	}
}

void Speed::print() const {
	const std::string strVT100ClearLine = "\33[2K\r";
	std::cout << strVT100ClearLine << "Speed: " << formatSpeed(this->getSpeed());
	
	// std::map is sorted by key so we'll always have the devices in numerical order
	for (auto it = m_mDeviceSamples.begin(); it != m_mDeviceSamples.end(); ++it) {
		std::cout << " GPU" << it->first << ": " << formatSpeed(this->getSpeed(it->second));
	}

	std::cout << "\r" << std::flush;
}

#ifndef _HPP_SPEED
#define _HPP_SPEED

#include <chrono>
#include <mutex>
#include <list>
#include <map>

class Speed {
public:
	typedef std::pair<long long, size_t> samplePair;
	typedef std::list<samplePair> sampleList;

public:
	Speed(const unsigned int intervalPrintMs = 500, const unsigned int intervalSampleMs = 10000);
	~Speed();

	void update(const unsigned int numPoints, const unsigned int indexDevice);
	void print() const;

	double getSpeed() const;
	double getSpeed(const unsigned int indexDevice) const;

private:
	double getSpeed(const sampleList & l) const;
	void updateList(const unsigned int & numPoints, const long long & ns, sampleList & l);

private:
	const unsigned int m_intervalPrintMs;
	const unsigned int m_intervalSampleMs;

	long long m_lastPrint;
	mutable std::recursive_mutex m_mutex;
	sampleList m_lSamples;
	std::map<unsigned int, sampleList> m_mDeviceSamples;
};

#endif /* _HPP_SPEED */
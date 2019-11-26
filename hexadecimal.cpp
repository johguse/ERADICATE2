#include "hexadecimal.hpp"
#include <stdexcept>

std::string::size_type hexValueNoException(char c) {
	if (c >= 'A' && c <= 'F') {
		c -= 'A' - 'a';
	}

	const std::string hex = "0123456789abcdef";
	const std::string::size_type ret = hex.find(c);
	return ret;
}

std::string::size_type hexValue(char c) {
	const std::string::size_type ret = hexValueNoException(c);
	if (ret == std::string::npos) {
		throw std::runtime_error("bad hex value");
	}

	return ret;
}

std::string parseHexadecimalBytes(std::string o) {
	std::string strRet;

	if (o.size() >= 2 && o.substr(0, 2) == "0x") {
		o.erase(0, 2);
	}

	if (o.size() % 2 != 0) {
		throw std::runtime_error("malformatted hexadecimal data");
	}

	for (size_t i = 0; i < o.size(); i += 2) {
		const auto val = hexValue(o[i]) * 16 + hexValue(o[i + 1]);
		strRet += val;
	}

	return strRet;
}

#include "hexadecimal.hpp"
#include <stdexcept>

std::string toHex(const uint8_t * const s, const size_t len) {
	std::string b("0123456789abcdef");
	std::string r;

	for (size_t i = 0; i < len; ++i) {
		const unsigned char h = s[i] / 16;
		const unsigned char l = s[i] % 16;

		r = r + b.substr(h, 1) + b.substr(l, 1);
	}

	return r;
}

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

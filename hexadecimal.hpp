#ifndef HPP_HEXADECIMAL
#define HPP_HEXADECIMAL

#include <string>
#include <cstdint>

std::string toHex(const uint8_t * const s, const size_t len);
std::string::size_type hexValueNoException(char c);
std::string::size_type hexValue(char c);
std::string parseHexadecimalBytes(std::string o);

#endif /* HPP_HEXADECIMAL */

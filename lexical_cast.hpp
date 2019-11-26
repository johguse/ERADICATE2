#ifndef HPP_LEXICALCAST
#define HPP_LEXICALCAST

#include <sstream>

namespace lexical_cast {
	template<typename T>
	std::string write(const T & o) {
		std::ostringstream s;
		s << o;
		return s.str();
	}

	template <typename T>
	T read(const std::string s) {
		std::istringstream ss(s);
		T t;
		ss >> t;
		return t;
	}
}

#endif /* HPP_LEXICALCAST */
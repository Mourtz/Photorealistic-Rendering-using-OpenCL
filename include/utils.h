#pragma once

#include <fstream>
#include <string>

namespace utils {

	inline std::string ReadFile(std::string filepath)
	{
		std::ifstream t(filepath);
		std::string str;

		t.seekg(0, std::ios::end);
		str.reserve(t.tellg());
		t.seekg(0, std::ios::beg);

		str.assign((std::istreambuf_iterator<char>(t)),
				std::istreambuf_iterator<char>());

		return str;
	}

	/**
	* Format a value of bytes into more readable units.
	* @param {size_t}  bytes
	* @param {float*}  bytesFloat
	* @param {string*} unit
	*/
	inline void formatBytes(std::size_t bytes, float* bytesFloat, std::string* unit) {
		*unit = std::string("bytes");
		*bytesFloat = (float)bytes;

		if (*bytesFloat >= 1024.0f) {
			*bytesFloat /= 1024.0f;
			*unit = std::string("KB");
		}
		if (*bytesFloat >= 1024.0f) {
			*bytesFloat /= 1024.0f;
			*unit = std::string("MB");
		}
		if (*bytesFloat >= 1024.0f) {
			*bytesFloat /= 1024.0f;
			*unit = std::string("GB");
		}
	}

	/**
	* Read the contents of a file as string.
	* @param  {const char*} filename Path to and name of the file.
	* @return {std::string}          File content as string.
	*/
	inline std::string loadFileAsString(const char* filename) {
		std::ifstream fileIn(filename);
		std::string content;

		while (fileIn.good()) {
			std::string line;
			std::getline(fileIn, line);
			content.append(line + "\n");
		}
		fileIn.close();

		return content;
	}

}

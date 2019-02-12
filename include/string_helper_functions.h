#pragma once

#include <iostream>
#include <algorithm> 
#include <string>
#include <vector>
#include <fstream>

// trim from start (in place)
inline void ltrim(std::string &s) {
	s.erase(s.begin(), find_if(s.begin(), s.end(), [](int ch) {
		return !isspace(ch);
	}));
}

// trim from end (in place)
inline void rtrim(std::string &s) {
	s.erase(find_if(s.rbegin(), s.rend(), [](int ch) {
		return !isspace(ch);
	}).base(), s.end());
}

// trim from both ends (in place)
inline void trim(std::string &s) {
	ltrim(s);
	rtrim(s);
}

std::vector<std::string> split(const std::string& str, const std::string& delim)
{
    using std::string;
    
    std::vector<string> tokens;
    unsigned int prev = 0, pos = 0;
    do
    {
        pos = str.find(delim, prev);
        if (pos == string::npos) pos = str.length();
        string token = str.substr(prev, pos-prev);
		trim(token);
        if (!token.empty()) tokens.push_back(token);
        prev = pos + delim.length();
    }
    while (pos < str.length() && prev < str.length());
    return tokens;
}

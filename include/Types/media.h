#pragma once

#ifndef EMSCRIPTEN
#include <CL/opencl.hpp>
#endif

struct cl_medium {
	cl_float density;
	cl_float sigmaA;
	cl_float sigmaS;
	cl_float sigmaT;
	bool absorptionOnly;
};

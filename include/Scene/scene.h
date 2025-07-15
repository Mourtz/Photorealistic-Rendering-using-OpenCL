#pragma once

#include <iostream>
#include <cstdlib>
#include <fstream>
#include <vector>
#include <string>


#ifndef EMSCRIPTEN
#include <CL/opencl.hpp>
#else
#include <cstdint>
typedef int32_t cl_int;
typedef uint32_t cl_uint;
typedef uint8_t cl_uchar;
typedef uint16_t cl_ushort;
typedef float cl_float;
typedef float cl_float16[16];
typedef bool cl_bool;
// Define cl_uint8 as a struct with s[8] for compatibility
typedef struct { uint8_t s[8]; } cl_uint8;
#if defined(EMSCRIPTEN)
typedef struct { float s[3]; } cl_float3;
typedef struct { float s[4]; } cl_float4;
typedef struct { unsigned int s[4]; } cl_uint4;
typedef uint64_t cl_ulong;
#endif
#endif


#ifndef EMSCRIPTEN
#include <rapidjson/document.h>
#include <rapidjson/istreamwrapper.h>
#endif

#include <Scene/geometry.h>
#include <Types/media.h>

extern std::string scene_filepath;


#ifndef EMSCRIPTEN
struct host_scene
{
	// ...existing code...
	// (full implementation as before)
};
#else
struct host_scene
{
	cl_uint8 object_count;
	std::vector<Mesh> cpu_meshes;
	cl_int MAX_BOUNCES = 12;
	cl_int MAX_DIFF_BOUNCES = 4;
	cl_int MAX_SPEC_BOUNCES = 4;
	cl_int MAX_TRANS_BOUNCES = 12;
	cl_int MAX_SCATTERING_EVENTS = 12;
	bool H_SPHERE = false;
	bool H_SDF = false;
	bool H_BOX = false;
	bool H_QUAD = false;
	int ACTIVE_MATS = 0;
	cl_uint LIGHT_COUNT = 0;
	std::vector<cl_uint> LIGHT_INDICES;
	cl_bool HAS_GLOBAL_MEDIUM = false;
	cl_medium GLOBAL_MEDIUM;
	cl_int MARCHING_STEPS = 128;
	cl_int SHADOW_MARCHING_STEPS = 64;
	cl_bool BUILD_BVH = false;
	std::string obj_path;
	Material *obj_mat = new Material();
	void getLights() {
		// stub for web build
	}
	template <typename T>
	void parseMaterial(T*, Material&) {
		// stub for web build
	}
	void load() {
		// stub for web build
	}
};
#endif

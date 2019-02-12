#pragma once

#include <CL/cl.hpp>

#include <align.h>
#include <material.h>

constexpr int TOTAL_GEOM_TYPES	= 4;
constexpr int SPHERE			= 1 << 0;
constexpr int BOX				= 1 << 1;
constexpr int SDF				= 1 << 2;
constexpr int QUAD				= 1 << 3;

constexpr int TOTAL_SDF_TYPES	= 4;
constexpr int SDF_SPHERE		= 1 << 5;
constexpr int SDF_BOX			= 1 << 6;
constexpr int SDF_ROUND_BOX		= 1 << 7;
constexpr int SDF_PLANE			= 1 << 8;

struct Mesh {
	Material mat;
	ALIGN(16)vec3 position;
	ALIGN(64)cl_float16 joker;
	int t;

	Mesh() : t(SPHERE) {}
};

#pragma once

#include <cstdint> 
#include <CL/cl.hpp>

#include <align.h>
#include <Types/material.h>

constexpr cl_uchar TOTAL_GEOM_TYPES	= 4;
constexpr cl_uchar SPHERE			= 1 << 0;
constexpr cl_uchar BOX				= 1 << 1;
constexpr cl_uchar SDF				= 1 << 2;
constexpr cl_uchar QUAD				= 1 << 3;

constexpr cl_uchar TOTAL_SDF_TYPES	= 4;
constexpr cl_uchar SDF_SPHERE		= 1 << 4;
constexpr cl_uchar SDF_BOX			= 1 << 5;
constexpr cl_uchar SDF_ROUND_BOX	= 1 << 6;
constexpr cl_uchar SDF_PLANE		= 1 << 7;

struct Mesh {
	Material mat;
	ALIGN(16)vec3 position;
	ALIGN(64)cl_float16 joker;
	cl_uchar t;

	Mesh() : t(SPHERE) {}
};

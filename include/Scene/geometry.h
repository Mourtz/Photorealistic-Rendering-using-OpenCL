#pragma once

#include <cstdint> 
#include <CL/cl.hpp>

#include <align.h>
#include <Types/material.h>

constexpr uint8_t TOTAL_GEOM_TYPES	= 4;
constexpr uint8_t SPHERE			= 1 << 0;
constexpr uint8_t BOX				= 1 << 1;
constexpr uint8_t SDF				= 1 << 2;
constexpr uint8_t QUAD				= 1 << 3;

constexpr uint8_t TOTAL_SDF_TYPES	= 4;
constexpr uint8_t SDF_SPHERE		= 1 << 4;
constexpr uint8_t SDF_BOX			= 1 << 5;
constexpr uint8_t SDF_ROUND_BOX		= 1 << 6;
constexpr uint8_t SDF_PLANE			= 1 << 7;

struct Mesh {
	Material mat;
	ALIGN(16)vec3 position;
	ALIGN(64)cl_float16 joker;
	cl_uchar t;

	Mesh() : t(SPHERE) {}
};

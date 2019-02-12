#pragma once

#include <CL/cl.hpp>

#include <align.h>
#include <Types/material.h>

const int TOTAL_GEOM_TYPES	= 4;
const int SPHERE			= 1 << 0;
const int BOX				= 1 << 1;
const int SDF				= 1 << 2;
const int QUAD				= 1 << 3;

const int TOTAL_SDF_TYPES	= 4;
const int SDF_SPHERE		= 1 << 5;
const int SDF_BOX			= 1 << 6;
const int SDF_ROUND_BOX		= 1 << 7;
const int SDF_PLANE			= 1 << 8;

struct Mesh {
	Material mat;
	ALIGN(16)vec3 position;
	ALIGN(64)cl_float16 joker;
	int t;

	Mesh() : t(SPHERE) {}
};

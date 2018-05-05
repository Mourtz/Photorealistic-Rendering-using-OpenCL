#pragma once

#include <align.h>
#include <map>
#include <Math/linear_algebra.h>

struct Texture
{
	ALIGN(16)vec3 color;
	ALIGN(16)vec3 emission;
};

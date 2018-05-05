#pragma once

#include <align.h>
#include <Texture/texture.h>

// total material types
const int TOTAL_MAT_TYPES = 9;

// Light
const int LIGHT		= 1 << 0;
// Diffuse
const int DIFF		= 1 << 1;
// Specular/Glossy
const int SPEC		= 1 << 2;
// Refractive
const int REFR		= 1 << 3;
// Coat
const int COAT		= 1 << 4;
// Bounded Homogeneous Medium
const int VOL		= 1 << 5;
// Translucent Subsurface Scattering
const int TRANS		= 1 << 6;
// Specular Subsurface Scattering
const int SPECSUB	= 1 << 7;
// Absorptive 1
const int ABS_REFR	= 1 << 8;
// Absorptive 2
const int ABS_REFR2 = 1 << 9;

// total texture types
const int TOTAL_TEX_TYPES = 4;

const int TEX_NULL	= 0;
const int TEX_1		= 1 << 0;
const int TEX_2		= 1 << 1;
const int TEX_3		= 1 << 2;
const int TEX_4		= 1 << 3;

struct Material
{
	ALIGN(16)vec3 color;
	float roughness;
	int t;
	int tex;
	bool b;

	Material() : color(vec3(1.0f)), roughness(0.0f), t(DIFF), tex(TEX_NULL), b(true) {}
	Material(vec3 _color, vec3 _emission, float _roughness, int _t, int _tex, bool _b) : color(_color), roughness(_roughness), t(_t), tex(_tex), b(_b) {}
};

const Material glass = Material();
#pragma once

#include <cstdint> 
#include <align.h>
#include <Texture/texture.h>

//------------------ MATERIAL TYPES ------------------ 
// Light
constexpr uint16_t LIGHT		= 1 << 0;
// Diffuse
constexpr uint16_t DIFF			= 1 << 1;
// Conductor
constexpr uint16_t COND			= 1 << 2;
// Rough Conductor
constexpr uint16_t ROUGH_COND	= 1 << 10;
// Dielectric
constexpr uint16_t DIEL			= 1 << 3;
// Rough Dielectric
constexpr uint16_t ROUGH_DIEL	= 1 << 11;
// Coat
constexpr uint16_t COAT			= 1 << 4;
// Bounded Homogeneous Medium
constexpr uint16_t VOL			= 1 << 5;
// Translucent Subsurface Scattering
constexpr uint16_t TRANS		= 1 << 6;
// Specular Subsurface Scattering
constexpr uint16_t SPECSUB		= 1 << 7;
// Absorptive 1
constexpr uint16_t ABS_REFR		= 1 << 8;
// Absorptive 2
constexpr uint16_t ABS_REFR2	= 1 << 9;

//------------------ LOBES ------------------ 

constexpr cl_uchar NullLobe                  = 0;
constexpr cl_uchar GlossyReflectionLobe      = (1 << 0);
constexpr cl_uchar GlossyTransmissionLobe    = (1 << 1);
constexpr cl_uchar DiffuseReflectionLobe     = (1 << 2);
constexpr cl_uchar DiffuseTransmissionLobe   = (1 << 3);
constexpr cl_uchar SpecularReflectionLobe    = (1 << 4);
constexpr cl_uchar SpecularTransmissionLobe  = (1 << 5);
constexpr cl_uchar AnisotropicLobe           = (1 << 6);
constexpr cl_uchar ForwardLobe               = (1 << 7);

constexpr cl_uchar GlossyLobe                = (  GlossyReflectionLobe |   GlossyTransmissionLobe);
constexpr cl_uchar DiffuseLobe               = ( DiffuseReflectionLobe |  DiffuseTransmissionLobe);
constexpr cl_uchar SpecularLobe              = (SpecularReflectionLobe | SpecularTransmissionLobe);

constexpr cl_uchar TransmissiveLobe          = (GlossyTransmissionLobe | DiffuseTransmissionLobe | SpecularTransmissionLobe);
constexpr cl_uchar ReflectiveLobe            = (GlossyReflectionLobe   | DiffuseReflectionLobe   | SpecularReflectionLobe);

constexpr cl_uchar AllLobes                  = (TransmissiveLobe | ReflectiveLobe | AnisotropicLobe);
constexpr cl_uchar AllButSpecular            = (~(SpecularLobe | ForwardLobe));

//------------------ TEXTURE TYPES ------------------ 

// total texture types
constexpr cl_uchar TOTAL_TEX_TYPES = 4;

constexpr cl_uchar TEX_NULL	= 0;
constexpr cl_uchar TEX_1		= 1 << 0;
constexpr cl_uchar TEX_2		= 1 << 1;
constexpr cl_uchar TEX_3		= 1 << 2;
constexpr cl_uchar TEX_4		= 1 << 3;

#define BECKMANN	1 << 0
#define PHONG		1 << 1
#define GGX			1 << 2
#define BLINN		1 << 3

// handy site to extract data 
// https://refractiveindex.info/

// @ToDo implement SPDs

// wavelengths
// 0.74 µm, 0.56 µm, 0.38 µm

#define BK7_eta	vec4(1.5121f, 1.5180f, 1.5337f)

// Copper (Cu) 
#define Cu_eta	vec4(0.29019f, 0.61122f, 1.2290f)
#define Cu_k	vec4(3.5080f, 2.7107f, 2.1706f)

// Gold (Au) 
#define Au_eta	vec4(0.17229f, 0.36901f, 1.5478f)
#define Au_k	vec4(4.2223f, 2.4628f, 1.8063f)

// Platinum (Pt) 
#define Pt_eta	vec4(2.6656f, 2.1114f, 1.6782f)
#define Pt_k	vec4(4.7023f, 3.7726f, 2.7284f)

//--------------------------------------------------- 

struct Material
{
	ALIGN(16)vec4 color;
	ALIGN(16)vec4 eta;
	ALIGN(16)vec4 k;
	float roughness;
	cl_ushort t;
	cl_uchar lobes;
	cl_uchar dist;

	Material() : color(vec4(1.0f, 1.0f, 1.0f, 0.0f)),
		eta(Au_eta),
		k(Au_k),
		roughness(0.0f),
		t(DIFF), 
		lobes(DiffuseLobe),
		dist(BECKMANN) {}

	Material(vec4 _color, float _roughness, uint16_t _t, cl_uchar _tex, bool _b) : color(_color),
		eta(Au_eta),
		k(Au_k),
		roughness(_roughness),
		t(_t), 
		lobes(NullLobe),
		dist(BECKMANN) {}
};

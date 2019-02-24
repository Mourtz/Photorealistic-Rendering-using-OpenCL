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

/*
//------------------ LOBES ------------------ 

constexpr uint8_t NullLobe                  = 0;
constexpr uint8_t GlossyReflectionLobe      = (1 << 0);
constexpr uint8_t GlossyTransmissionLobe    = (1 << 1);
constexpr uint8_t DiffuseReflectionLobe     = (1 << 2);
constexpr uint8_t DiffuseTransmissionLobe   = (1 << 3);
constexpr uint8_t SpecularReflectionLobe    = (1 << 4);
constexpr uint8_t SpecularTransmissionLobe  = (1 << 5);
constexpr uint8_t AnisotropicLobe           = (1 << 6);
constexpr uint8_t ForwardLobe               = (1 << 7);

constexpr uint8_t GlossyLobe                = (  GlossyReflectionLobe |   GlossyTransmissionLobe);
constexpr uint8_t DiffuseLobe               = ( DiffuseReflectionLobe |  DiffuseTransmissionLobe);
constexpr uint8_t SpecularLobe              = (SpecularReflectionLobe | SpecularTransmissionLobe);

constexpr uint8_t TransmissiveLobe          = (GlossyTransmissionLobe | DiffuseTransmissionLobe | SpecularTransmissionLobe);
constexpr uint8_t ReflectiveLobe            = (GlossyReflectionLobe   | DiffuseReflectionLobe   | SpecularReflectionLobe);

constexpr uint8_t AllLobes                  = (TransmissiveLobe | ReflectiveLobe | AnisotropicLobe);
constexpr uint8_t AllButSpecular            = (~(SpecularLobe | ForwardLobe));
*/

//------------------ TEXTURE TYPES ------------------ 

// total texture types
constexpr uint8_t TOTAL_TEX_TYPES = 4;

constexpr uint8_t TEX_NULL	= 0;
constexpr uint8_t TEX_1		= 1 << 0;
constexpr uint8_t TEX_2		= 1 << 1;
constexpr uint8_t TEX_3		= 1 << 2;
constexpr uint8_t TEX_4		= 1 << 3;

//--------------------------------------------------- 

struct Material
{
	ALIGN(16)vec4 color;
	float roughness;
	cl_ushort t;
	cl_uchar tex;
	bool b;

	Material() : color(vec4(1.0f, 1.0f, 1.0f, 0.0f)), roughness(0.0f), t(DIFF), tex(TEX_NULL), b(true) {}
	Material(vec4 _color, float _roughness, uint16_t _t, uint8_t _tex, bool _b) : color(_color), roughness(_roughness), t(_t), tex(_tex), b(_b) {}
};

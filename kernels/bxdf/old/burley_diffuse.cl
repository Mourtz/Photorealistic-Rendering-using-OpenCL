#ifndef __BURLEY_DIFF__
#define __BURLEY_DIFF__

#FILE:bxdf/diffuse.cl

float FSchlickDiffuse(float F90, float NoX){
	return 1.0f + (F90 - 1.0f) * pow(1.0f - NoX, 5.0f);
}

float3 DiffuseBurley(float3 albedo, float roughness, float NoV, float NoL, float VoH){
	float energyBias = mix(0.0f, 0.5f, roughness);
	float energyFactor = mix(1.0f, 1.0f / 1.51f, roughness);
	float FD90 = energyBias + 2.0f * VoH * VoH * roughness;
	float FdV = FSchlickDiffuse(FD90, NoV);
	float FdL = FSchlickDiffuse(FD90, NoL);
	return albedo * FdV * FdL * energyFactor * INV_PI;
}

#endif
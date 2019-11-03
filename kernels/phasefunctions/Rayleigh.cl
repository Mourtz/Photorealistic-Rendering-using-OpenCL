#ifndef __RAYLEIGH__
#define __RAYLEIGH__

inline float rayleigh(float cosTheta) {
	return (3.0f / (16.0f*PI))*(1.0f + cosTheta * cosTheta);
}

float3 phase_eval(const float3 wi, const float3 wo) {
	return (float3)(rayleigh(dot(wi,wo)));
}

float phase_pdf(const float3 wi, const float3 wo) {
	return rayleigh(dot(wi, wo));
}

bool phase_sample(
	const float3 wi, PhaseSample* phaseSample,
	RNG_SEED_PARAM
) {
	float2 xi = next2D(RNG_SEED_VALUE);
	float phi = xi.x*TWO_PI;
	float z = xi.y*4.0f - 2.0f;
	float invZ = sqrt(z*z + 1.0f);
	float u = cbrt(z + invZ);

	float cosTheta = u - 1.0f / u;
	float sinTheta = sqrt(fmax(1.0f - cosTheta * cosTheta, 0.0f));

	TangentFrame tf = createTangentFrame(&wi);
	phaseSample->w = toGlobal(&tf, (float3)(
		native_cos(phi) * sinTheta,
		native_sin(phi) * sinTheta,
		cosTheta
	));

	phaseSample->weight = (float3)(1.0f);
	phaseSample->pdf = rayleigh(cosTheta);
	return true;
}

#endif

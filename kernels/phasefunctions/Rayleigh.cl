#ifndef __RAYLEIGH__
#define __RAYLEIGH__

#ifndef ortho

#define ortho(v) fabs(v.x) > fabs(v.y) ? F3_UP : F3_RIGHT

void calc_binormals(const float3 normal, float3* tangent, float3* binormal) {
	*binormal = fast_normalize(cross(normal, ortho(normal)));
	*tangent = cross(normal, *binormal);
}

#endif

float rayleigh(float cosTheta) {
	return (3.0f / (16.0f*PI))*(1.0f + cosTheta * cosTheta);
}

float3 rayleigh_eval(const float3 wi, const float3 wo) {
	return (float3)(rayleigh(dot(wi,wo)));
}

bool rayleigh_sample(
	const float3 wi, PhaseSample* p_sample,
	RNG_SEED_PARAM
) {
	float2 xi = (float2)(next1D(RNG_SEED_VALUE), next1D(RNG_SEED_VALUE));
	float phi = xi.x*TWO_PI;
	float z = xi.y*4.0f - 2.0f;
	float invZ = sqrt(z*z + 1.0f);
	float u = cbrt(z + invZ);

	float cosTheta = u - 1.0f / u;
	float sinTheta = sqrt(fmax(1.0f - cosTheta * cosTheta, 0.0f));

	float3 u, v;
	calc_binormals(wi, &u, &v);
	p_sample->w =
		u * cos(phi)*sinTheta +
		v * sin(phi)*sinTheta +
		wi * cosTheta;

	p_sample->weight = 1.0f;
	p_sample->pdf = rayleigh(cosTheta);
	return true;
}

#endif

#ifndef __GGX__
#define __GGX__

/*---------------------------------- GGX ----------------------------------*/
float DistributionGGX(float cosTheta, float alpha) {
	float alpha2 = alpha * alpha;
	return alpha2 * INV_PI / pow(cosTheta * cosTheta * (alpha2 - 1.0f) + 1.0f, 2.0f);
}

float3 SampleGGX(float3 n, float alpha, float* cosTheta, uint* seed0, uint* seed1) {
	float phi = TWO_PI * get_random(seed0, seed1);
	float xi = get_random(seed0, seed1);
	*cosTheta = native_sqrt((1.0f - xi) / (xi * (alpha * alpha - 1.0f) + 1.0f));
	float sinTheta = native_sqrt(fmax(0.0f, 1.0f - (*cosTheta) * (*cosTheta)));

	float3 t, s;
	calc_binormals(n, &s, &t);

	return fast_normalize(s*native_cos(phi)*sinTheta + t * native_sin(phi)*sinTheta + n * (*cosTheta));
}

#endif

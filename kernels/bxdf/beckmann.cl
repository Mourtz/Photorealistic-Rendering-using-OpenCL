#ifndef __BECKMANN__
#define __BECKMANN__

/*---------------------------------- BECKMANN ----------------------------------*/
float DistributionBeckmann(float3 normal, float3 wh, float alpha) {
	float cosTheta2 = dot(normal, wh);
	cosTheta2 *= cosTheta2;
	float alpha2 = alpha * alpha;

	return exp(-(1.0f / cosTheta2 - 1.0f) / alpha2) * INV_PI / (alpha2 * cosTheta2 * cosTheta2);
}

float3 SampleBeckmann(float3 n, float alpha, uint* seed0, uint* seed1) {
	float phi = TWO_PI * get_random(seed0, seed1);
	float cosTheta = sqrt(1.0f / (1.0f - alpha * alpha * log(get_random(seed0, seed1))));
	float sinTheta = sqrt(1.0f - cosTheta * cosTheta);

	float3 axis = fabs(n.x) > 0.001f ? (float3)(0.0f, 1.0f, 0.0f) : (float3)(1.0f, 0.0f, 0.0f);
	float3 t = normalize(cross(axis, n));
	float3 s = cross(n, t);

	return normalize(s*cos(phi)*sinTheta + t * sin(phi)*sinTheta + n * cosTheta);
}

#endif

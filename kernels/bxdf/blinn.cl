#ifndef __BLINN__
#define __BLINN__

/*---------------------------------- BLINN ----------------------------------*/
float DistributionBlinn(float3 normal, float3 wh, float alpha) {
	return (alpha + 2.0f) * pow(max(0.0f, dot(normal, wh)), alpha) * INV_TWO_PI;
}

float3 SampleBlinn(float3 n, float alpha, uint* seed0, uint* seed1) {
	float phi = TWO_PI * get_random(seed0, seed1);
	float cosTheta = pow(get_random(seed0, seed1), 1.0f / (alpha + 1.0f));
	float sinTheta = sqrt(1.0f - cosTheta * cosTheta);

	float3 axis = fabs(n.x) > 0.001f ? (float3)(0.0f, 1.0f, 0.0f) : (float3)(1.0f, 0.0f, 0.0f);
	float3 t = normalize(cross(axis, n));
	float3 s = cross(n, t);

	return normalize(s*cos(phi)*sinTheta + t * sin(phi)*sinTheta + n * cosTheta);
}

#endif

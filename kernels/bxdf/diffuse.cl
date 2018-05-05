#ifndef __DIFFUSE__
#define __DIFFUSE__

float3 cosWeightedRandomHemisphereDirection(const float3 w, uint* seed0, uint* seed1) {
#if 0
	float3 u, v;
	calc_binormals(w, &u, &v);

	float rand1 = get_random(seed0, seed1) * TWO_PI;
	float rand2 = get_random(seed1, seed0);
	float rand2s = native_sqrt(rand2);

	return fast_normalize(u * native_cos(rand1)*rand2s + v * native_sin(rand1)*rand2s + w * native_sqrt(1.0f - rand2));
#else
	float theta = get_random(seed0, seed1) * TWO_PI;
	float cosT = get_random(seed0, seed1);
	float sinT = native_sqrt(1.0 - cosT * cosT);
	float3 tangent = fast_normalize(cross(w.yzx, w));
	float3 binormal = cross(w, tangent);
	return fast_normalize((tangent * native_cos(theta) + binormal * native_sin(theta)) * sinT + w * cosT);
#endif
}

#endif

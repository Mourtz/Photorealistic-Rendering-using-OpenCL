#ifndef __VALUE_NOISE__
#define __VALUE_NOISE__

#define value_hash hash_1f32_1f32

float value_noise(const float3 x){ 
	const float3 step = (float3)(110.0f, 241.0f, 171.0f);

	float3 i;
	float3 f = fract(x,&i);

	// For performance, compute the base input to a 1D value_hash from the integer part of the argument and the 
	// incremental change to the 1D based on the 3D -> 1D wrapping
	float n = dot(i, step);

	float3 u = f * f * (3.0f - 2.0f * f);
	return mix(mix(mix(value_hash(n + dot(step, F3_ZERO)), value_hash(n + dot(step, F3_RIGHT)), u.x),
		mix(value_hash(n + dot(step, F3_UP)), value_hash(n + dot(step, (float3)(1.0f, 1.0f, 0.0f))), u.x), u.y),
		mix(mix(value_hash(n + dot(step, F3_FRONT)), value_hash(n + dot(step, (float3)(1.0f, 0.0f, 1.0f))), u.x),
		mix(value_hash(n + dot(step, (float3)(0, 1, 1))), value_hash(n + dot(step, F3_ONE)), u.x), u.y), u.z);
}

float value_fbm(
	float3 x, const int octaves
){
	float v = 0.0f;			// value
	float a = 0.5f;			// amplitude
	const float g = 0.5f;	// gain
	const float l = 2.0f;	// lacunarity

	// remove tiling artifacts
	const float3 shift = (float3)(100.0f);

	for (int i = 0; i < octaves; ++i) {
		v += a * value_noise(x);
		x = x * l + shift;
		a *= g;
	}
	return v;
}

#undef value_hash

#endif
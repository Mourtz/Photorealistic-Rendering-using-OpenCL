#ifndef __PRNG__
#define __PRNG__

union prng_r { float f; uint ui; };

uint BJXorShift(uint x){
	x += x << 10u;
	x ^= x >> 6u;
	x += x << 3u;
	x ^= x >> 11u;
	x += x << 15u;

	return x;
}

uint GMXorShift(uint x){
	x ^= x << 13u;
	x ^= x >> 17u;
	x ^= x << 5u;

	return x;
}

uint WangHash(uint x){
	x = (x ^ 61u) ^ (x >> 16u);
	x *= 9u;
	x ^= x >> 4u;
	x *= 0x27d4eb2du;
	x ^= x >> 15u;

	return x;
}

float get_random(uint *seed0, uint *seed1) {

	/* hash the seeds */
	*seed0 = 36969 * ((*seed0) & 65535) + ((*seed0) >> 16);
	*seed1 = 18000 * ((*seed1) & 65535) + ((*seed1) >> 16);

	uint ires = ((*seed0) << 16) + (*seed1);

	union prng_r res;

	res.ui = (ires & 0x007fffff) | 0x40000000;
	return (res.f - 2.0f) * 0.5f;
}

/* https://learnopengl.com/PBR/IBL/Specular-IBL */
float RadicalInverse_VdC(uint bits){
	bits = (bits << 16u) | (bits >> 16u);
	bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
	bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
	bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
	bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
	return (float)(bits) * 2.3283064365386963e-10f; // / 0x100000000
}
float2 Hammersley(uint i, uint N){
	return (float2)((float)(i) / (float)(N), RadicalInverse_VdC(i));
}

#ifdef SIN_HASH
#define hash(seed)	fract(sin(seed)*43758.5453123f)
#define hash2(seed) fract(sin(seed)*(float2)(43758.5453123f,22578.1459123f))
#define hash3(seed)	fract(sin(seed)*(float3)(43758.5453123f,22578.1459123f,19642.3490423f))
#endif

#endif
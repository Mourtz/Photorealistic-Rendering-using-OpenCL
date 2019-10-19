#ifndef __PRNG__
#define __PRNG__

#if RNG_TYPE == 0
inline float get_random(RNG_SEED_PARAM) {
	/* hash the seeds */
	*seed0 = 36969 * ((*seed0) & 65535) + ((*seed0) >> 16);
	*seed1 = 18000 * ((*seed1) & 65535) + ((*seed1) >> 16);

	uint ires = ((*seed0) << 16) + (*seed1);

	union_32 res;

	res.ui = (ires & 0x007fffff) | 0x40000000;
	return (res.f - 2.0f) * 0.5f;
}
#elif RNG_TYPE == 1
inline float get_random(RNG_SEED_PARAM) {
	ulong oldState = *state;
	*state = oldState * 6364136223846793005UL + 1;
	uint xorShifted = (uint)(((oldState >> 18u) ^ oldState) >> 27u);
	uint rot = oldState >> 59u;
	return normalizedUint((xorShifted >> rot) | (xorShifted << ((uint)(-(int)(rot)) & 31)));
}
#elif RNG_TYPE == 2
inline float get_random(RNG_SEED_PARAM) {
	float fl;
	return fract(sin(*seed += 0.2f) * 43758.5453123f, &fl);
}
#endif

#define nextBoolean(c, RNG_SEED_VALUE) (get_random(RNG_SEED_VALUE) < c)
#define hash_2ui_2f32(RNG_SEED_VALUE) (float2)(get_random(RNG_SEED_VALUE), get_random(RNG_SEED_VALUE))

#if 0

//---------------------------------- SIN HASH ----------------------------------

// 1f32 -> 1f32
float hash_1f32_1f32(float seed) {
	float fl;
#if 1
	return fract(sin(seed)*43758.5453123f, &fl);
#else
	float res = fract(seed*43758.5453123f, &fl);
	return fract(dot(res, res*(fl*213.321f)), &fl);
#endif
}
// 1f32 -> 2f32
float2 hash_1f32_2f32(float seed) {
#if 1
	float2 fl;
	return fract(sin(seed)*(float2)(43758.5453123f,22578.1459123f), &fl);
#else
	float n = hash_1f32_1f32(seed);
	return (float2)(n, hash_1f32_1f32(n+seed));
#endif
}
// 1f32 -> 3f32
float3 hash_1f32_3f32(float seed){
#if 1
	float3 fl;
	return fract(sin(seed)*(float3)(43758.5453123f,22578.1459123f,19642.3490423f), &fl);
#else
	float n0 = hash_1f32_1f32(seed);
	float n1 = hash_1f32_1f32(seed+n0);
	return (float3)(n0, n1, hash_1f32_1f32(seed+n0+n1));
#endif
}

//---------------------------- HAMMERSLEY ----------------------------

float VanDerCorpus(uint n, uint base){
    float invBase = 1.0f / (float)(base);
    float denom   = 1.0f;
    float result  = 0.0f;

    for(uint i = 0; i < 32; ++i){
        if(n > 0){
            denom   = fmod((float)(n), 2.0f);
            result += denom * invBase;
            invBase = invBase * 0.5f;
            n       = (uint)((float)(n) * 0.5f);
        }
    }

    return result;
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

//--------------------------------------------------------------------

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
#endif

#endif

#pragma once
#include <stdint.h>
#include <Math/linear_algebra.h>

namespace PRNG
{
// single iteration of Bob Jenkins' One-At-A-Time hashing algorithm:
//  http://www.burtleburtle.net/bob/hash/doobs.html
// suggestes by Spatial on stackoverflow:
//  http://stackoverflow.com/questions/4200224/random-noise-functions-for-glsl
inline uint32_t BJXorShift(uint32_t x)
{
	x += x << 10u;
	x ^= x >> 6u;
	x += x << 3u;
	x ^= x >> 11u;
	x += x << 15u;

	return x;
}

// xor-shift algorithm by George Marsaglia
//  https://www.thecodingforums.com/threads/re-rngs-a-super-kiss.704080/
// suggestes by Nathan Reed:
//  http://www.reedbeta.com/blog/quick-and-easy-gpu-random-numbers-in-d3d11/
inline uint32_t GMXorShift(uint32_t x)
{
	x ^= x << 13u;
	x ^= x >> 17u;
	x ^= x << 5u;

	return x;
}

// hashing algorithm by Thomas Wang
//  http://www.burtleburtle.net/bob/hash/integer.html
// suggestes by Nathan Reed:
//  http://www.reedbeta.com/blog/quick-and-easy-gpu-random-numbers-in-d3d11/
inline uint32_t WangHash(uint32_t x)
{
	x = (x ^ 61u) ^ (x >> 16u);
	x *= 9u;
	x ^= x >> 4u;
	x *= 0x27d4eb2du;
	x ^= x >> 15u;

	return x;
}

// classic sin hash function
inline float sinHash(float seed)
{
	return fract(sin(seed) * 43758.5453123);
}

inline vec2 sinHash2(float seed)
{
	return vec2(sin(seed) * 43758.5453123, sin(seed) * 22578.1459123);
}

inline vec3 sinHash3(float seed)
{
	return vec3(sin(seed) * 43758.5453123, sin(seed) * 22578.1459123, sin(seed) * 19642.3490423);
}

} // namespace PRNG

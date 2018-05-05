#pragma once

#include <cmath>

#ifndef M_PI
#define M_PI 3.14156265
#endif

#ifndef PI_OVER_TWO
#define PI_OVER_TWO 1.5707963267948966192313216916397514420985
#endif

struct vec2
{
	union {
		struct { float x, y; };
		float _v[2];
	};

	vec2(float _x = 0.0f, float _y = 0.0f) : x(_x), y(_y) {}
	vec2(const vec2& v) : x(v.x), y(v.y) {}
	inline vec2 operator*(float a) const { return vec2(x*a, y*a); }
	inline vec2 operator/(float a) const { return vec2(x / a, y / a); }
	inline vec2 operator*(const vec2& v) const { return vec2(x * v.x, y * v.y); }
	inline vec2 operator+(const vec2& v) const { return vec2(x + v.x, y + v.y); }
	inline vec2 operator-(const vec2& v) const { return vec2(x - v.x, y - v.y); }
};

//-------------------------------------------------------------------------------------------------

struct vec4
{
	union {
		struct { float x, y, z, w; };
		float _v[4];
	};

	// constructors
	vec4()											: x(0.0f), y(0.0f), z(0.0f), w(0.0f) {}
	vec4(float val)									: x(val), y(val), z(val), w(val) {}
	vec4(float _x, float _y)						: x(_x), y(_y), z(0.0), w(0.0) {}
	vec4(float _x, float _y, float _z)				: x(_x), y(_y), z(_z), w(0.0) {}
	vec4(float _x, float _y, float _z, float _w)	: x(_x), y(_y), z(_z), w(_w) {}
	vec4(const vec4& v)								: x(v.x), y(v.y), z(v.z), w(v.w) {}

	// operators

	inline float& operator[](const int i) { if (i == 0) return x; else if (i == 1) return y; else if (i == 2) return z; else return w; }
	inline float  operator[](const int i) const { if (i == 0) return x; else if (i == 1) return y; else if (i == 2) return z; else return w; }

	inline vec4 operator+(float a) const { return vec4(x + a, y + a, z + a, w + a); }
	inline vec4 operator-(float a) const { return vec4(x - a, y - a, z - a, w - a); }
	inline vec4 operator*(float a) const { return vec4(x * a, y * a, z * a, w * a); }
	inline vec4 operator/(float a) const { return vec4(x / a, y / a, z / a, w / a); }

	inline vec4 operator+(const vec4& v) const { return vec4(x + v.x, y + v.y, z + v.z, w + v.w); }
	inline vec4 operator-(const vec4& v) const { return vec4(x - v.x, y - v.y, z - v.z, w - v.w); }
	inline vec4 operator*(const vec4& v) const { return vec4(x * v.x, y * v.y, z * v.z, w * v.w); }
	inline vec4 operator/(const vec4& v) const { return vec4(x / v.x, y / v.y, z / v.z, w / v.w); }

	inline vec4& operator+=(const float& a) { return *this=(*this + a); }
	inline vec4& operator+=(const vec4& v) { return *this=(*this + v); }

	inline vec4& operator-=(const float& a) { return *this=(*this - a); }
	inline vec4& operator-=(const vec4& v) { return *this=(*this - v); }

	inline vec4& operator*=(const float& a) { return *this=(*this * a); }
	inline vec4& operator*=(const vec4& v) { return *this=(*this * v); }

	inline vec4& operator/=(const float& a) { return *this=(*this / a); }
	inline vec4& operator/=(const vec4& v) { return *this=(*this / v); }

	inline bool operator!=(const vec4& v) { return x != v.x || y != v.y || z != v.z; }

	//-------------------------------------------------------------------------------------------------

	inline float lengthsq3() { return sqrtf(x * x + y * y + z * z); }
	inline float lengthsq4() { return sqrtf(x * x + y * y + z * z + w * w); }

	// only for 3D vectors!
	inline void normalize() { float norm = sqrtf(x * x + y * y + z * z); *this = *this / norm; }
};

inline vec4 operator+(const float& f, const vec4& v) { return v + f; }
inline vec4 operator-(const float& f, const vec4& v) { return vec4(f) - v; }
inline vec4 operator*(const float& f, const vec4& v) { return v * f; }
inline vec4 operator/(const float& f, const vec4& v) { return vec4(f) / v; }

inline vec4 min4(const vec4& v1, const vec4& v2){ return vec4(fmin(v1.x, v2.x), fmin(v1.y, v2.y), fmin(v1.z, v2.z), fmin(v1.w, v2.w)); }
inline vec4 max4(const vec4& v1, const vec4& v2){ return vec4(fmax(v1.x, v2.x), fmax(v1.y, v2.y), fmax(v1.z, v2.z), fmax(v1.w, v2.w)); }

//-------------------------------------------------------------------------------------------------

// OpenCL handles vec3 exactly the same as vec4
#define vec3 vec4

inline vec3 cross(const vec3& v1, const vec3& v2) { return vec3(v1.y*v2.z - v1.z*v2.y, v1.z*v2.x - v1.x*v2.z, v1.x*v2.y - v1.y*v2.x); }
inline float dot(const vec3& v1, const vec3& v2) { return v1.x*v2.x + v1.y*v2.y + v1.z*v2.z; }
inline float distancesq(const vec3& v1, const vec3& v2) { return (v1.x - v2.x)*(v1.x - v2.x) + (v1.y - v2.y)*(v1.y - v2.y) + (v1.z - v2.z)*(v1.z - v2.z); }
inline float distance(const vec3& v1, const vec3& v2) { return sqrtf((v1.x - v2.x)*(v1.x - v2.x) + (v1.y - v2.y)*(v1.y - v2.y) + (v1.z - v2.z)*(v1.z - v2.z)); }
inline vec3 normalize(const vec3& v) { float norm = sqrtf(v.x * v.x + v.y * v.y + v.z * v.z); return v / norm; }

inline vec3 min3(const vec3& v1, const vec3& v2) { return vec3(fmin(v1.x, v2.x), fmin(v1.y, v2.y), fmin(v1.z, v2.z)); }
inline vec3 max3(const vec3& v1, const vec3& v2) { return vec3(fmax(v1.x, v2.x), fmax(v1.y, v2.y), fmax(v1.z, v2.z)); }

//-------------------------------------------------------------------------------------------------

inline float fract(float x) { return (x - floor(x)); }

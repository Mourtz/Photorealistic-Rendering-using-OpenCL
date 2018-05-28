#ifndef __UTILS__
#define __UTILS__

#FILE:prng/prng.cl

/* fractional part */
#define fract(x) x-floor(x)
/* max component */
#define fmax2(v) fmax(v.x, v.y)
#define fmax3(v) fmax(fmax(v.x, v.y), v.z)
#define fmax4(v) fmax(fmax(fmax(v.x, v.y), v.z),v.w)
/* min component */
#define fmin2(v) fmin(v.x, v.y)
#define fmin3(v) fmin(fmin(v.x, v.y), v.z)
#define fmin4(v) fmin(fmin(fmin(v.x, v.y), v.z),v.w)
/* average */
#define avg2(v) (dot(v, 1.0f)*0.5f)
#define avg3(v) (dot(v, 1.0f)*0.3333333333333333333333333333333333333333333333f)
#define avg4(v) (dot(v, 1.0f)*0.25f)
/* linear interpolation */
#define lerp(a, b, w) (a + w * (b - a))

/* equirectangular mapping */
#define envMapEquirect(dir) (float2)((atan2(dir.z, dir.x) * INV_TWO_PI) + 0.5f, acos(dir.y) * INV_PI)

/// Translate cartesian coordinates to spherical system
void CartesianToSpherical(float3 cart, float* r, float* phi, float* theta)
{
	float temp = atan2(cart.x, cart.z);
	*r = sqrt(cart.x*cart.x + cart.y*cart.y + cart.z*cart.z);
	/* Account for discontinuity */
	*phi = (float)((temp >= 0) ? temp : (temp + 2 * PI));
	*theta = acos(cart.y / *r);
}

/// Translate polar coordinates to cartesian
float3 polar_to_cartesian(const float sinTheta, const float cosTheta,
	const float sinPhi, const float cosPhi)
{
	return (float3)(sinTheta * cosPhi,
		sinTheta * sinPhi,
		cosTheta);
}

#define ortho(v) fabs(v.x) > fabs(v.y) ? F3_UP : F3_RIGHT

void calc_binormals(const float3 normal, float3* tangent, float3* binormal) {
	*binormal = fast_normalize(cross(normal, ortho(normal)));
	*tangent = cross(normal, *binormal);
}

#endif

#ifndef __UTILS__
#define __UTILS__

#FILE:prng/prng.cl

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


//--------------------------------------------------------------------

float3 uniformSphere(const float2 xi){
	float phi = xi.x*TWO_PI;
	float z = xi.y*2.0f - 1.0f;
	float r = native_sqrt(fmax(1.0f - z * z, 0.0f));

	return (float3)(
		native_cos(phi)*r,
		native_sin(phi)*r,
		z
	);
}

float uniformSpherePdf(){
    return INV_FOUR_PI;
}

//--------------------------------------------------------------------

float3 uniformSphericalCap(const float2 xi, const float cosThetaMax){
	float phi = xi.x*TWO_PI;
	float z = xi.y*(1.0f - cosThetaMax) + cosThetaMax;
	float r = native_sqrt(fmax(1.0f - z * z, 0.0f));
	return (float3)(
		native_cos(phi)*r,
		native_sin(phi)*r,
		z
	);
}

float uniformSphericalCapPdf(float cosThetaMax){
    return INV_TWO_PI/(1.0f - cosThetaMax);
}

//--------------------------------------------------------------------

float3 cosineHemisphere(const float2* xi){ 
    float phi = xi->x*TWO_PI;
    float r = native_sqrt(xi->y);
    return (float3)(
		native_cos(phi)*r,
		native_sin(phi)*r,
		native_sqrt(fmax(1.0f - xi->y, 0.0f))
    );
}

float cosineHemispherePdf(const float3 p){
    return fabs(p.z)*INV_PI;
}

//--------------------------------------------------------------------

float3 phongHemisphere(const float2* xi, float n){
    float phi = xi->x*TWO_PI;
    float cosTheta = pow(xi->y, 1.0f/(n + 1.0f));
    float r = native_sqrt(fmax(1.0f - cosTheta*cosTheta, 0.0f));
    return (float3)(native_cos(phi)*r, native_sin(phi)*r, cosTheta);
}

float phongHemispherePdf(const float3* v, float n){
    return INV_TWO_PI*(n + 1.0f)*pow(v->z, n);
}

//--------------------------------------------------------------------

#endif

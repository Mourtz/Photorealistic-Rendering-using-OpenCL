#ifndef __UTILS__
#define __UTILS__

typedef union { half f;		ushort ui;	short i; 	} union_16;
typedef union { float f;	uint ui;	int i;		} union_32;
typedef union { double f;	ulong ui;	long i;		} union_64;

inline float uintBitsToFloat(uint i){
	union_32 unionHack;
	unionHack.ui = i;
	return unionHack.f;
}

inline uint floatBitsToUint(float f){
	union_32 unionHack;
	unionHack.f = f;
	return unionHack.ui;
}

// 2x-5x faster than i/float(UINT_MAX)
inline float normalizedUint(uint i){
	return uintBitsToFloat((i >> 9u) | 0x3F800000u) - 1.0f;
}

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

/* Signum that exludes 0 */
#define sgnE(T) (T < 0.0f ? -1.0f : 1.0f)

/* equirectangular mapping */
#define envMapEquirect(dir) (float2)((atan2(dir.z, dir.x) * INV_TWO_PI) + 0.5f, acos(dir.y) * INV_PI)

#define DiracAcceptanceThreshold 1e-3f

inline bool checkReflectionConstraint(const float3* wi, const float3* wo){
	return fabs(wi->z * wo->z - wi->x * wo->x - wi->y * wo->y - 1.0f) < DiracAcceptanceThreshold;
}

inline bool checkRefractionConstraint(const float3* wi, const float3* wo, float eta, float cosThetaT)
{
	float dotP = -wi->x * wo->x * eta - wi->y * wo->y * eta - copysign(cosThetaT, wi->z) * wo->z;
	return fabs(dotP - 1.0f) < DiracAcceptanceThreshold;
}

inline float invertPhi(float3 w, float mu){
    float result = (w.x == 0.0f && w.y == 0.0f) ? mu*INV_TWO_PI : atan2(w.y, w.x)*INV_TWO_PI;
	result += (result < 0.0f);
    return result;
}

/// Translate cartesian coordinates to spherical system
void CartesianToSpherical(
	float3 cart, 
	float* r, float* phi, float* theta
){
	float temp = atan2(cart.x, cart.z);
	*r = sqrt(cart.x*cart.x + cart.y*cart.y + cart.z*cart.z);
	/* Account for discontinuity */
	*phi = (float)((temp >= 0) ? temp : (temp + 2 * PI));
	*theta = acos(cart.y / *r);
}

/// Translate polar coordinates to cartesian
inline float3 polar_to_cartesian(
	const float sinTheta, const float cosTheta,
	const float sinPhi, const float cosPhi
){
	return (float3)(sinTheta * cosPhi,
		sinTheta * sinPhi,
		cosTheta);
}

#define trigInverse(x) fmin(native_sqrt(fmax(1.0f - x*x, 0.0f)), 1.0f)

//--------------------------------------------------------------------

inline float3 uniformSphere(const float2 xi){
	float phi = xi.x*TWO_PI;
	float z = xi.y*2.0f - 1.0f;
	float r = native_sqrt(fmax(1.0f - z * z, 0.0f));

	return (float3)(
		native_cos(phi)*r,
		native_sin(phi)*r,
		z
	);
}

#define uniformSpherePdf() INV_FOUR_PI
#define invertUniformSphere(w, mu) (float2)(invertPhi(w, mu), (w.z + 1.0f)*0.5f)

//--------------------------------------------------------------------

inline float3 uniformHemisphere(const float2* xi){
    float phi  = TWO_PI*xi->x;
    float r = native_sqrt(fmax(1.0f - xi->y*xi->y, 0.0f));
    return (float3)(native_cos(phi)*r, native_sin(phi)*r, xi->y);
}

#define uniformHemispherePdf() INV_TWO_PI
#define invertUniformHemisphere(w, mu) (float2)(invertPhi(w, mu), w.z)

//--------------------------------------------------------------------

inline float3 uniformSphericalCap(const float2 xi, const float cosThetaMax){
	float phi = xi.x*TWO_PI;
	float z = xi.y*(1.0f - cosThetaMax) + cosThetaMax;
	float r = native_sqrt(fmax(1.0f - z * z, 0.0f));
	return (float3)(
		native_cos(phi)*r,
		native_sin(phi)*r,
		z
	);
}

#define uniformSphericalCapPdf(cosThetaMax) INV_TWO_PI/(1.0f - cosThetaMax)
inline bool invertUniformSphericalCap(float3 w, float cosThetaMax, float2* xi, float mu)
{
    float xiY = (w.z - cosThetaMax)/(1.0f - cosThetaMax);
    if (xiY >= 1.0f || xiY < 0.0f)
        return false;

    *xi = (float2)(invertPhi(w, mu), xiY);
    return true;
}

//--------------------------------------------------------------------

inline float3 cosineHemisphere(const float2 xi){ 
    float phi = xi.x*TWO_PI;
    float r = native_sqrt(xi.y);
    return (float3)(
		native_cos(phi)*r,
		native_sin(phi)*r,
		native_sqrt(fmax(1.0f - xi.y, 0.0f))
    );
}

inline float cosineHemispherePdf(float3 p) { return  fabs(p.z) * INV_PI; }
inline float2 invertCosineHemisphere(float3 w, float mu) {
	return (float2)(invertPhi(w, mu), fmax(1.0f - w.z * w.z, 0.0f));
}

//--------------------------------------------------------------------

inline float3 phongHemisphere(const float2* xi, float n){
    float phi = xi->x*TWO_PI;
    float cosTheta = pow(xi->y, 1.0f/(n + 1.0f));
    float r = native_sqrt(fmax(1.0f - cosTheta*cosTheta, 0.0f));
    return (float3)(native_cos(phi)*r, native_sin(phi)*r, cosTheta);
}

#define phongHemispherePdf(v, n) INV_TWO_PI*(n + 1.0f)*pow(v->z, n)
#define invertPhongHemisphere(w, n, mu) (float2)(invertPhi(w, mu), pow(w.z, n + 1.0f))

//--------------------------------------------------------------------

#endif

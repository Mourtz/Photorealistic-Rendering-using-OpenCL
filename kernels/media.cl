#ifndef __MEDIA__
#define __MEDIA__

typedef struct {
	float3 w;
	float weight;
	float pdf;
} PhaseSample;

typedef struct {
	float3 p;
	float continuedT;
	/*float3 continuedWeight;*/
	float t;
	float3 weight;
	float pdf;
	bool exited;
} MediumSample;

typedef struct {
	float3 density;
	float3 sigmaA;
	float3 sigmaS;
	float3 sigmaT;
	bool absorptionOnly;
} Medium;

//----------------------------------------------------

#ifdef LIGHT

/* only for point and sphere lights */
void sampleEquiAngular(
	const Ray* ray,
	const float Xi,
	const float3 lightPos,
	float* dist,
	float* pdf
){
	// get coord of closest point to light along (infinite) ray
	float delta = dot(lightPos - ray->origin, ray->dir);

	// get distance this point is from light
	float D = length(ray->origin + delta * ray->dir - lightPos);

	// get angle of endpoints
	float thetaA = atan2(0.0f - delta, D);
	float thetaB = atan2(ray->t - delta, D);

	// take sample
	float t = D * tan(mix(thetaA, thetaB, Xi));
	*dist = delta + t;
	*pdf = D / ((thetaB - thetaA)*(D*D + t*t));
}

#endif

//----------------------------------------------------

#FILE:phasefunctions/HenyeyGreenstein.cl
#FILE:media/homogeneous.cl

#endif

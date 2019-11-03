#ifndef __BXDF__
#define __BXDF__

#FILE:bxdf/microfacet.cl
#FILE:bxdf/Fresnel.cl

/*-------------- LAMBERTIAN ---------------*/
#FILE:bxdf/materials/Lambert.cl

/*----------------- FIBER -----------------*/

float lambertianCylinder(const float3* wo){
    float cosThetaO = trigInverse(wo->y);
    float phi = atan2(wo->x, wo->z);
    if (phi < 0.0f)
        phi += TWO_PI;

    return cosThetaO*fabs(((PI - phi)*native_cos(phi) + native_sin(phi))*INV_FOUR_PI);
}

void LambertianFiberBCSDF(
	Ray* ray, SurfaceScatterEvent* res,
	const Material* mat, 
	RNG_SEED_PARAM
){
	float h = next1D(RNG_SEED_VALUE)*2.0f - 1.0f;
	float nx = h;
    float nz = trigInverse(nx);

	float3 d = cosineHemisphere(next2D(RNG_SEED_VALUE));

	ray->dir = (float3)(d.z*nx + d.x*nz, d.y, d.z*nz - d.x*nx);

	res->pdf = lambertianCylinder(&ray->dir);
    res->weight = mat->color;

	ray->origin = ray->pos + ray->normal * EPS;
	ray->dir = toGlobal(&res->frame, ray->dir);
}

#define LambertianFiberBCSDF_pdf(ray) lambertianCylinder(&ray->dir)

/*---------- DIELECTRIC ----------*/
#FILE:bxdf/materials/Dielectric.cl
#FILE:bxdf/materials/RoughDielectric.cl

/*---------- CONDUCTOR ----------*/
#FILE:bxdf/materials/Conductor.cl
#FILE:bxdf/materials/RoughConductor.cl

/*---------- COAT ----------*/
#FILE:bxdf/materials/Coat.cl


//------------------------------------------------------------------

bool BSDF(
	SurfaceScatterEvent* event,
	const Ray* ray,
	const Scene* scene,
	const Material* mat,
	RNG_SEED_PARAM
) {

#ifdef DIFF
	if (mat->t & DIFF)
#else
	if (false)
#endif
	{
		return LambertBSDF(ray, event, mat, RNG_SEED_VALUE);
	}
#ifdef COND
	else if (mat->t & COND)
	{
		return ConductorBSDF(ray, event, mat, RNG_SEED_VALUE);
	}
#endif
#ifdef ROUGH_COND
	else if (mat->t & ROUGH_COND)
	{
		return RoughConductorBSDF(ray, event, mat, RNG_SEED_VALUE);
	}
#endif
#ifdef DIEL
	else if (mat->t & DIEL)
	{
		return DielectricBSDF(ray, event, mat, RNG_SEED_VALUE);
	}
#endif
#ifdef ROUGH_DIEL
	else if (mat->t & ROUGH_DIEL) {
		return RoughDielectricBSDF(ray, event, mat, RNG_SEED_VALUE);
	}
#endif
#ifdef COAT
	else if (mat->t & COAT) {
		return CoatBSDF(ray, event, mat, RNG_SEED_VALUE);
	}
#endif

	return false;
}

bool BSDF2(
	SurfaceScatterEvent* event,
	const Ray* ray,
	const Scene* scene,
	const Material* mat,
	RNG_SEED_PARAM,
	bool adjoint
) {
	if (!BSDF(event, ray, scene, mat, RNG_SEED_VALUE))
		return false;

	if (adjoint) {
		event->weight *= fabs(
			(dot(toGlobal(&event->frame, event->wo), event->frame.normal) * event->wi.z) /
			(dot(toGlobal(&event->frame, event->wi), event->frame.normal) * event->wo.z)); // TODO: Optimize
	}
#if defined(DIEL) || defined(ROUGH_DIEL)
	else {
		float eta = 1.0f;
#ifdef DIEL
		if (mat->t & DIEL)
#else
		if (false)
#endif
		{
			eta = DielectricBSDF_eta(event, mat);
		}
#ifdef ROUGH_DIEL
		else if (mat->t & ROUGH_DIEL) {
			eta = RoughDielectricBSDF_eta(event, mat);
		}
#endif

		event->weight *= pow(eta, 2.0f);
	}
#endif

	return true;
}

//------------------------------------------------------------------

float3 BSDF_eval(
	const SurfaceScatterEvent* event,
	const Material* mat
) {

#ifdef DIFF
	if (mat->t & DIFF)
#else
	if (false)
#endif
	{
		return LambertBSDF_eval(event, mat);
	}
#ifdef COND
	else if (mat->t & COND)
	{
		return ConductorBSDF_eval(event, mat);
	}
#endif
#ifdef ROUGH_COND
	else if (mat->t & ROUGH_COND)
	{
		return RoughConductorBSDF_eval(event, mat);
	}
#endif
#ifdef DIEL
	else if (mat->t & DIEL)
	{
		return DielectricBSDF_eval(event, mat);
	}
#endif
#ifdef ROUGH_DIEL
	else if (mat->t & ROUGH_DIEL) {
		return RoughDielectricBSDF_eval(event, mat);
	}
#endif
#ifdef COAT
	else if (mat->t & COAT) {
		return CoatBSDF_eval(event, mat);
	}
#endif

	return (float3)(0.0f);
}

float3 BSDF_eval2(
	const SurfaceScatterEvent* event,
	const Material* mat,
	bool adjoint
) {
	float3 f = BSDF_eval(event, mat);

	if (adjoint) {
		f *= fabs(
			(dot(toGlobal(&event->frame, event->wo), event->frame.normal) * event->wi.z) /
			(dot(toGlobal(&event->frame, event->wi), event->frame.normal) * event->wo.z)); // TODO: Optimize
	}
#if defined(DIEL) || defined(ROUGH_DIEL)
	else {
		float eta = 1.0f;
#ifdef DIEL
		if (mat->t & DIEL)
#else
		if(false)
#endif
		{
			eta = DielectricBSDF_eta(event, mat);
		}
#ifdef ROUGH_DIEL
		else if (mat->t & ROUGH_DIEL) {
			eta = RoughDielectricBSDF_eta(event, mat);
		}
#endif

		f *= pow(eta, 2.0f);
	}
#endif

	return f;
}


//------------------------------------------------------------------

float BSDF_pdf(
	const SurfaceScatterEvent* event,
	const Material* mat
) {
#ifdef DIFF
	if (mat->t & DIFF)
#else
	if (false)
#endif
	{
		return LambertBSDF_pdf(event);
	}
#ifdef COND
	else if (mat->t & COND)
	{
		return ConductorBSDF_pdf(event);
	}
#endif
#ifdef ROUGH_COND
	else if (mat->t & ROUGH_COND)
	{
		return RoughConductorBSDF_pdf(event, mat);
	}
#endif
#ifdef DIEL
	else if (mat->t & DIEL)
	{
		return DielectricBSDF_pdf(event, mat);
	}
#endif
#ifdef ROUGH_DIEL
	else if (mat->t & ROUGH_DIEL) {
		return RoughDielectricBSDF_pdf(event, mat);
	}
#endif
#ifdef COAT
	else if (mat->t & COAT) {
		return CoatBSDF_pdf(event, mat);
	}
#endif

	return 0.0f;
}

/*
#ifdef __BURLEY_DIFF__
	float3 H = fast_normalize(ray->incomingRayDir + ray->dir);
	float NoV = clamp(dot(ray->normal, ray->incomingRayDir), EPS, 1.0f);
	float NoL = clamp(dot(ray->normal, ray->dir), EPS, 1.0f);
	float VoH = clamp(dot(ray->incomingRayDir, H), EPS, 1.0f);

	return DiffuseBurley(mat->color, fmax(mat->roughness, EPS2), NoV, NoL, VoH);
#else
*/

#endif

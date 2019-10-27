#ifndef __BXDF__
#define __BXDF__

#FILE:bxdf/microfacet.cl

#define reflect(dir, n) (dir - 2.0f * dot(n, dir) * n)

/* Schlick's approximation of Fresnel equation */
float schlick(const float3 dir, const float3 n, const float nc, const float nt) {
	float R0 = pow((nc - nt) / (nc + nt), 2.0f);
	return R0 + (1.0f - R0) * pow(1.0f + dot(n, dir), 5.0f);
}

/* Full Fresnel equation */
float fresnel(const float3 dir, const float3 n, const float nc, const float nt, const float3 refr) {
	float cosI = dot(dir, n);
	float costT = dot(n, refr);

	float Rs = pow((nc * cosI - nt * costT) / (nc * cosI + nt * costT), 2.0f);
	float Rp = pow((nc * costT - nt * cosI) / (nc * costT + nt * cosI), 2.0f);
	return (Rs + Rp) * 0.5f;
}

float3 refract(const float3 dir, const float3 nl, const float eta) {
	float k = 1.0f - eta * eta * (1.0f - dot(nl, dir) * dot(nl, dir));

	if (k < 0.0f)
		return (float3)(0.0f);
	else
		return eta * dir - (eta * dot(nl, dir) + sqrt(k)) * nl;
}

// From "PHYSICALLY BASED LIGHTING CALCULATIONS FOR COMPUTER GRAPHICS" by Peter Shirley
// http://www.cs.virginia.edu/~jdl/bib/globillum/shirley_thesis.pdf
float conductorReflectance(float eta, float k, float cosThetaI){
	float cosThetaISq = cosThetaI * cosThetaI;
	float sinThetaISq = fmax(1.0f - cosThetaISq, 0.0f);
	float sinThetaIQu = sinThetaISq * sinThetaISq;

	float innerTerm = eta * eta - k * k - sinThetaISq;
	float aSqPlusBSq = native_sqrt(fmax(innerTerm*innerTerm + 4.0f*eta*eta*k*k, 0.0f));
	float a = native_sqrt(fmax((aSqPlusBSq + innerTerm)*0.5f, 0.0f));

	float Rs = ((aSqPlusBSq + cosThetaISq) - (2.0f*a*cosThetaI)) /
		((aSqPlusBSq + cosThetaISq) + (2.0f*a*cosThetaI));
	float Rp = ((cosThetaISq*aSqPlusBSq + sinThetaIQu) - (2.0f*a*cosThetaI*sinThetaISq)) /
		((cosThetaISq*aSqPlusBSq + sinThetaIQu) + (2.0f*a*cosThetaI*sinThetaISq));

	return 0.5f*(Rs + Rs * Rp);
}

float3 conductorReflectance3(float3 eta, float3 k, float cosThetaI){
    return (float3)(
        conductorReflectance(eta.x, k.x, cosThetaI),
        conductorReflectance(eta.y, k.y, cosThetaI),
        conductorReflectance(eta.z, k.z, cosThetaI)
    );
}

float conductorReflectanceApprox(float eta, float k, float cosThetaI){
    float cosThetaISq = cosThetaI*cosThetaI;
    float ekSq = eta*eta* + k*k;
    float cosThetaEta2 = cosThetaI*2.0f*eta;

    float Rp = (ekSq*cosThetaISq - cosThetaEta2 + 1.0f)/(ekSq*cosThetaISq + cosThetaEta2 + 1.0f);
    float Rs = (ekSq - cosThetaEta2 + cosThetaISq)/(ekSq + cosThetaEta2 + cosThetaISq);
    return (Rs + Rp)*0.5f;
}

inline float dielectricReflectance(float eta, float cosThetaI, float *cosThetaT){
    if (cosThetaI < 0.0f) {
        eta = 1.0f/eta;
        cosThetaI = -cosThetaI;
    }
    float sinThetaTSq = eta*eta*(1.0f - cosThetaI*cosThetaI);
    if (sinThetaTSq > 1.0f) {
        *cosThetaT = 0.0f;
        return 1.0f;
    }
    *cosThetaT = native_sqrt(fmax(1.0f - sinThetaTSq, 0.0f));

    float Rs = (eta*cosThetaI - *cosThetaT)/(eta*cosThetaI + *cosThetaT);
    float Rp = (eta*(*cosThetaT) - cosThetaI)/(eta*(*cosThetaT) + cosThetaI);

    return (Rs*Rs + Rp*Rp)*0.5f;
}

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

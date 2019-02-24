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

float dielectricReflectance(float eta, float cosThetaI, float *cosThetaT){
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

float3 importance_sample_ggx(float2 random, const TangentFrame* tf, float alpha2) {
	float phi = TWO_PI * random.x;
	float cos_theta = native_sqrt((1.0f - random.y) / (1.0f + (alpha2 - 1.0f) * random.y));
	float sin_theta = native_sqrt(1.0f - cos_theta * cos_theta);

	float3 h = (float3)(sin_theta * native_cos(phi), sin_theta * native_sin(phi), cos_theta);

	return toGlobal(tf, h);
}

float3 importance_sample_beckmann(float2 random, const TangentFrame* tf, float alpha2) {
	float phi = TWO_PI * random.x;
	float cos_theta = native_sqrt(1.0f / (1.0f - alpha2 * log(random.y)));
	float sin_theta = native_sqrt(1.0f - cos_theta * cos_theta);

	float3 h = (float3)(sin_theta * native_cos(phi), sin_theta * native_sin(phi), cos_theta);

	return toGlobal(tf, h);
}

/*---------------------------------- LAMBERTIAN ----------------------------------*/

void LambertBSDF(
	Ray* ray, SurfaceScatterEvent* res,
	const Material* mat, 
	uint* seed0, uint* seed1
){ 
	float2 xi = (float2)(get_random(seed0, seed1), get_random(seed0, seed1));
	ray->dir = cosineHemisphere(&xi);

	res->pdf = cosineHemispherePdf(ray->dir);
	res->weight = mat->color;

	ray->origin = ray->pos + ray->normal * EPS;
	ray->dir = toGlobal(&ray->tf, ray->dir);
}

#define LambertBSDF_eval(ray, mat) mat->color*INV_PI*ray->dir.z
#define LambertBSDF_pdf(ray) cosineHemispherePdf(ray->dir)

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
	uint* seed0, uint* seed1
){
	float h = get_random(seed0, seed1)*2.0f - 1.0f;
	float nx = h;
    float nz = trigInverse(nx);

	float2 xi = hash_2ui_2f32(seed0, seed1);
	float3 d = cosineHemisphere(&xi);

	ray->dir = (float3)(d.z*nx + d.x*nz, d.y, d.z*nz - d.x*nx);

	res->pdf = lambertianCylinder(&ray->dir);
    res->weight = mat->color;

	ray->origin = ray->pos + ray->normal * EPS;
	ray->dir = toGlobal(&ray->tf, ray->dir);
}

#define LambertianFiberBCSDF_pdf(ray) lambertianCylinder(&ray->dir)

/*---------------------------------- DIELECTRIC ----------------------------------*/

bool DielectricBSDF(
	Ray* ray, SurfaceScatterEvent* res,
	const Material* mat, 
	uint* seed0, uint* seed1
){
	float3 wi = toLocal(&ray->tf, -ray->dir);
	float3 wo;

	const float ior = 1.5f;
	const float eta = wi.z < 0.0f ? ior : 1.0f/ior;

	float cosThetaT = 0.0f;
    float F = dielectricReflectance(eta, fabs(wi.z), &cosThetaT);

	if(get_random(seed0, seed1) < F){ 
		wo = (float3)(-wi.x, -wi.y, wi.z);
		res->pdf = F;
	} else { 
		if(F == 1.0f)
			return false;

		wo = (float3)(-wi.x*eta, -wi.y*eta, -copysign(cosThetaT, wi.z));
		res->pdf = 1.0f - F;
	}

	const bool ABS1 = mat->t & ABS_REFR, ABS2 = mat->t & ABS_REFR2;
	if(ABS1 | ABS2){
		res->weight = ABS2 ? mat->color : 1.0f; 
		res->weight = ray->backside ? exp(-ray->t * ((ABS1) ? mat->color : 1.0f) * 10.0f) : 1.0f;
	} else { 
		res->weight = mat->color;
	}

	ray->dir = toGlobal(&ray->tf, wo);
	ray->origin = ray->pos + ray->dir * EPS;

	return true;
}

bool RoughDielectricBSDF(
	const int dist,
	Ray* ray, SurfaceScatterEvent* res,
	const Material* mat, 
	uint* seed0, uint* seed1
){
	const float3 wi = toLocal(&ray->tf, -ray->dir);
	const float wiDotN = wi.z;

	float3 wo;

	const float ior = 1.5f;
	const float eta = wiDotN < 0.0f ? ior : 1.0f/ior;

	float sampleRoughness = (1.2f - 0.2f*native_sqrt(fabs(wiDotN)))*mat->roughness;
    float alpha = roughnessToAlpha(dist, mat->roughness);
    float sampleAlpha = roughnessToAlpha(dist, sampleRoughness);

	float3 m = Microfacet_sample(dist, sampleAlpha, hash_2ui_2f32(seed0, seed1));
	float pm = Microfacet_pdf(dist, sampleAlpha, m);

	if (pm < 1e-10f)
		return false;

	float wiDotM = dot(wi, m);
    float cosThetaT = 0.0f;
	float F = dielectricReflectance(1.0f/ior, wiDotM, &cosThetaT);
	float etaM = wiDotM < 0.0f ? ior : 1.0f/ior;

	bool reflect = get_random(seed0, seed1) < F;

	if (reflect)
		wo = 2.0f*wiDotM*m - wi;
	else
		wo = (etaM*wiDotM - sgnE(wiDotM)*cosThetaT)*m - etaM*wi;

	float woDotN = wo.z;

	bool reflected = wiDotN*woDotN > 0.0f;
	if (reflected != reflect)
		return false;

	float woDotM = dot(wo, m);
	float G = Microfacet_G(dist, alpha, wi, wo, m);
	float D = Microfacet_D(dist, alpha, m);
	
	const bool ABS1 = mat->t & ABS_REFR, ABS2 = mat->t & ABS_REFR2;

	res->weight = fabs(wiDotM)*G*D/(fabs(wiDotN)*pm);
	if(ABS1 | ABS2){
		res->weight *= ABS2 ? mat->color : 1.0f; 
		res->weight *= ray->backside ? exp(-ray->t * ((ABS1) ? mat->color : 1.0f) * 10.0f) : 1.0f;
	} else { 
		res->weight *= mat->color;
	}

	if (reflect)
        res->pdf = (F)*pm*0.25f/fabs(wiDotM);
    else
        res->pdf = (1.0f - F)*pm*fabs(woDotM)/pow(eta*wiDotM + woDotM, 2.0f);
	
	ray->dir = toGlobal(&ray->tf, wo);
	ray->origin = ray->pos + ray->dir * EPS;

	return true;
}

/*---------------------------------- CONDUCTOR ----------------------------------*/

bool Conductor(
	Ray* ray, SurfaceScatterEvent* res,
	const Material* mat, 
	uint* seed0, uint* seed1
){ 
	float3 wi = toLocal(&ray->tf, -ray->dir);
	
	// Silver (Ag) 
	float F = conductorReflectance(0.051585f, 3.9046f, wi.z);

	res->pdf = 1.0f;
	res->weight = F*mat->color;

	ray->origin = ray->pos + ray->normal * EPS;
	ray->dir = toGlobal(&ray->tf, (float3)(-wi.x, -wi.y, wi.z));

	return true;
}

bool RoughConductor(
	const int dist,
	Ray* ray, SurfaceScatterEvent* res,
	const Material* mat, 
	uint* seed0, uint* seed1
){ 
	float3 wi = toLocal(&ray->tf, -ray->dir);
	
	if(wi.z <= 0.0f)
		return false;

	float alpha = roughnessToAlpha(dist, mat->roughness);

	float3 m = Microfacet_sample(dist, alpha, hash_2ui_2f32(seed0, seed1));
	float wiDotM = dot(wi, m);
	float3 wo = 2.0f*wiDotM*m - wi;
	if (wiDotM <= 0.0f || wo.z <= 0.0f)
		return false;
	float G = Microfacet_G(dist, alpha, wi, wo, m);
	float D = Microfacet_D(dist, alpha, m);
	float mPdf = Microfacet_pdf(dist, alpha, m);
	float pdf = mPdf*0.25f/wiDotM;
	float weight = wiDotM*G*D/(wi.z*mPdf);
	// Copper (Cu) 
	float3 F = conductorReflectance3((float3)(0.200438f, 0.924033f, 1.10221f), (float3)(3.91295f, 2.45285f, 2.14219f), wiDotM);

	res->pdf = pdf;
	res->weight = mat->color*F*weight;

	ray->origin = ray->pos + ray->normal * EPS;
	ray->dir = toGlobal(&ray->tf, wo);

	return true;
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

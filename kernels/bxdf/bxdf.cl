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

/*---------------------------------- DIFFUSE ----------------------------------*/

void LambertBSDF(Ray* ray, uint* seed0, uint* seed1){ 
	float2 xi = (float2)(get_random(seed0, seed1), get_random(seed0, seed1));
	ray->origin = ray->pos + ray->normal * EPS;
	ray->dir = toGlobal(&ray->tf, cosineHemisphere(&xi));
	//*pdf = cosineHemispherePdf(ray->dir);
}

void LambertianFiberBCSDF(Ray* ray, uint* seed0, uint* seed1){
	float h = get_random(seed0, seed1)*2.0f - 1.0f;
	float nx = h;
    float nz = trigInverse(nx);

	float2 xi = hash_2ui_2f32(seed0, seed1);
	float3 d = cosineHemisphere(&xi);

	ray->origin = ray->pos + ray->normal * EPS;
	ray->dir = toGlobal(&ray->tf, (float3)(d.z*nx + d.x*nz, d.y, d.z*nz - d.x*nx));
}

/*---------------------------------- SPECULAR ----------------------------------*/

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
	// Aluminium 
	float F = conductorReflectance(1.0972f, 6.7942f, wiDotM);

	res->pdf = pdf;
	res->weight = F*weight;

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

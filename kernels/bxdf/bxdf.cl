#ifndef __BXDF__
#define __BXDF__

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

float3 randomSphereDirection(uint* seed0, uint* seed1){
	float2 r = (float2)(get_random(seed0, seed1), get_random(seed0, seed1)) * TWO_PI;
	return (float3)(native_sin(r.x) * (float2)(native_sin(r.y), native_cos(r.y)), native_cos(r.x));
}

float3 uniformSphere(const float2 xi){
	float phi = xi.x*TWO_PI;
	float z = xi.y*2.0f - 1.0f;
	float r = sqrt(fmax(1.0f - z * z, 0.0f));

	return (float3)(
		cos(phi)*r,
		sin(phi)*r,
		z
	);
}

float3 uniformSphericalCap(const float2 xi, const float cosThetaMax){
	float phi = xi.x*TWO_PI;
	float z = xi.y*(1.0f - cosThetaMax) + cosThetaMax;
	float r = sqrt(fmax(1.0f - z * z, 0.0f));
	return (float3)(
		cos(phi)*r,
		sin(phi)*r,
		z
	);
}

float3 randomDirectionInHemisphere(const float3 n, uint* seed0, uint* seed1){
	float3 dr = randomSphereDirection(seed0, seed1);
	return dot(dr, n) * dr;
}


/*------------------------------------------------------------------------------*/

/* active materials */
#FILE:bxdf/ggx.cl
#FILE:bxdf/diffuse.cl

/*---------------------------------- SPECULAR ----------------------------------*/
bool sampleSpecular(Ray * ray, float4* res, const Material* mat, const uint* seed0, const uint* seed1) {

	ray->origin = ray->pos + ray->normal * EPS;

#ifdef __GGX__
	if (mat->roughness) {
		const float3 wo = -ray->dir;

		float cosTheta;
		float3 wh = SampleGGX(ray->normal, mat->roughness, &cosTheta, seed0, seed1);

		ray->dir = reflect(-wo, wh);

		if (dot(ray->dir, ray->normal) * dot(wo, ray->normal) < 0.0f) return false;

		float D = DistributionGGX(cosTheta, mat->roughness);
		float F = conductorReflectance(1.0f / 1.5f, 1.2f, dot(ray->dir, wh));

		*res = (float4)(D*F / (4.0f * dot(wo, ray->normal)) * mat->color, D * cosTheta / (4.0f * dot(wo, wh)));
		return true;
	}
	else {
		ray->dir = fast_normalize(reflect(ray->dir, ray->normal));
		*res = (float4)(mat->color, 1.0f);
		return true;
	}
#else
	ray->dir = fast_normalize(mat->roughness * randomDirectionInHemisphere(ray->normal, seed0, seed1) + reflect(ray->dir, ray->normal));
	*res = (float4)(mat->color, 1.0f);
	return true;
#endif

}

#ifdef __DIFFUSE__
	float3 SampleDiffuse(Ray* ray, const Material* mat, uint* seed0, uint* seed1) {
		ray->origin = ray->pos + ray->normal * EPS;
		ray->dir = cosWeightedRandomHemisphereDirection(ray->normal, seed0, seed1);

#ifdef __BURLEY_DIFF__
		float3 H = fast_normalize(ray->incomingRayDir + ray->dir);
		float NoV = clamp(dot(ray->normal, ray->incomingRayDir), EPS, 1.0f);
		float NoL = clamp(dot(ray->normal, ray->dir), EPS, 1.0f);
		float VoH = clamp(dot(ray->incomingRayDir, H), EPS, 1.0f);

		return DiffuseBurley(mat->color, fmax(mat->roughness, EPS2), NoV, NoL, VoH);
#else
		return mat->color;
#endif
	}
#else
#define SampleDiffuse(ray, mat, seed0, seed1) { printf("%s\n", "you haven't imported the diffuse module in the kernel!\n"); break; }
#endif

#endif

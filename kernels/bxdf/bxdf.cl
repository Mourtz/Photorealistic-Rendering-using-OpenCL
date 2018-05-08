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

float f_schlick_f32(float v_dot_h, float f0) {
	return f0 + (1.0f - f0) * pown(1.0f - v_dot_h, 5);
}

float3 f_schlick(float v_dot_h, float3 f0) {
	return (float3)(
		f_schlick_f32(v_dot_h, f0.x),
		f_schlick_f32(v_dot_h, f0.y),
		f_schlick_f32(v_dot_h, f0.z)
	);
}

/*---------------------------------- BECKMANN ----------------------------------*/

float D_Beckmann(float3 normal, float3 wh, float alpha2) {
	float cosTheta2 = dot(normal, wh);
	cosTheta2 *= cosTheta2;

	return exp(-(1.0f / cosTheta2 - 1.0f) / alpha2) * INV_PI / (alpha2 * cosTheta2 * cosTheta2);
}

float3 importance_sample_beckmann(float2 random, float3 normal, float alpha2) {
	float phi = TWO_PI * random.x;
	float cos_theta = native_sqrt(1.0f / (1.0f - alpha2 * log(random.y)));
	float sin_theta = native_sqrt(1.0f - cos_theta * cos_theta);

	float3 h = (float3)(sin_theta * native_cos(phi), sin_theta * native_sin(phi), cos_theta);

	float3 tangent, binormal;
	calc_binormals(normal, &tangent, &binormal);
	return tangent * h.x + binormal * h.y + normal * h.z;
}


/*---------------------------------- GGX ----------------------------------*/

float3 importance_sample_ggx(float2 random, float3 normal, float alpha2) {
	float phi = TWO_PI * random.x;
	float cos_theta = native_sqrt((1.0f - random.y) / (1.0f + (alpha2 - 1.0f) * random.y));
	float sin_theta = native_sqrt(1.0f - cos_theta * cos_theta);

	float3 h = (float3)(sin_theta * native_cos(phi), sin_theta * native_sin(phi), cos_theta);

	float3 tangent, binormal;
	calc_binormals(normal, &tangent, &binormal);
	return tangent * h.x + binormal * h.y + normal * h.z;
}

float g_smith_joint_lambda(float x_dot_n, float alpha2){
	float a = native_recip(x_dot_n * x_dot_n) - 1.0f;
	return (0.5f * native_sqrt(1.0f + alpha2 * a) - 0.5f);
}

float g_smith_joint(float l_dot_n, float v_dot_n, float alpha2) {
	float lambda_l = g_smith_joint_lambda(l_dot_n, alpha2);
	float lambda_v = g_smith_joint_lambda(v_dot_n, alpha2);
	return native_recip(1.0f + lambda_l + lambda_v);
}

bool sampleGGX(Ray * ray, float3* res, const Material* mat, const uint* seed0, const uint* seed1) {

	float roughness = fmax(mat->roughness, 1e-3f);

	float alpha2 = roughness * roughness;
	float3 hlf = importance_sample_ggx((float2)(get_random(seed0, seed1), get_random(seed0, seed1)), ray->normal, alpha2);
	float3 new_dir = reflect(ray->dir, hlf);

	if (dot(ray->normal, new_dir) < EPS) {
		return false;
	}
	else {
		float3 view = -ray->dir;
		float v_dot_n = clamp(dot(view, ray->normal), 0.0f, 1.0f);
		float l_dot_n = clamp(dot(new_dir, ray->normal), 0.0f, 1.0f);
		float v_dot_h = clamp(dot(view, hlf), 0.0f, 1.0f);
		float h_dot_n = clamp(dot(hlf, ray->normal), 0.0f, 1.0f);

		// Masking-shadowing
		float g = g_smith_joint(l_dot_n, v_dot_n, alpha2);

		float3 f = f_schlick(v_dot_h, mat->color);

		float3 weight = f * clamp(g * v_dot_h / (h_dot_n * v_dot_n), 0.0f, 1.0f);
		*res = mat->color*weight;

		ray->origin = ray->pos + ray->normal * EPS;
		ray->dir = new_dir;
	}

	return true;
}

/*------------------------------------------------------------------------------*/

/* active materials */
#FILE:bxdf/diffuse.cl

/*---------------------------------- DIFFUSE ----------------------------------*/

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

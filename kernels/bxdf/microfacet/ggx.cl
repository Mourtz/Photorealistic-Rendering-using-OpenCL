#ifndef __GGX__
#define __GGX__

float GGX_D(float alpha, const float3 m){
	if (m.z <= 0.0f)
		return 0.0f;

	float alphaSq = alpha * alpha;
	float cosThetaSq = m.z * m.z;
	float tanThetaSq = fmax(1.0f - cosThetaSq, 0.0f) / cosThetaSq;
	float cosThetaQu = cosThetaSq * cosThetaSq;
	return alphaSq * INV_PI / (cosThetaQu * native_powr(alphaSq + tanThetaSq, 2.0f));
}

float GGX_G1(float alpha, const float3 v, const float3 m) {
	if (dot(v, m) * v.z <= 0.0f)
		return 0.0f;

	float alphaSq = alpha * alpha;
	float cosThetaSq = v.z * v.z;
	float tanThetaSq = fmax(1.0f - cosThetaSq, 0.0f) / cosThetaSq;
	return 2.0f / (1.0f + native_sqrt(1.0f + alphaSq * tanThetaSq));
}

float GGX_G(float alpha, const float3 i, const float3 o, const float3 m) {
	return GGX_G1(alpha, i, m) * GGX_G1(alpha, o, m);
}

float GGX_pdf(float alpha, const float3 m){
	return GGX_D(alpha, m) * m.z;
}

float3 GGX_sample(float alpha, float2 xi) {
	float phi = xi.y * TWO_PI;
	float tanThetaSq = alpha * alpha * xi.x / (1.0f - xi.x);
	float cosTheta = 1.0f / native_sqrt(1.0f + tanThetaSq);

	float r = native_sqrt(fmax(1.0f - cosTheta * cosTheta, 0.0f));
	return (float3)(native_cos(phi) * r, native_sin(phi) * r, cosTheta);
}

/*
float3 importance_sample_ggx(float2 random, const TangentFrame* tf, float alpha2) {
	float phi = TWO_PI * random.x;
	float cos_theta = native_sqrt((1.0f - random.y) / (1.0f + (alpha2 - 1.0f) * random.y));
	float sin_theta = native_sqrt(1.0f - cos_theta * cos_theta);

	float3 h = (float3)(sin_theta * native_cos(phi), sin_theta * native_sin(phi), cos_theta);

	return toGlobal(tf, h);
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

bool sampleGGX(Ray* ray, float3* res, const Material* mat, const uint* seed0, const uint* seed1) {

	float roughness = fmax(mat->roughness, 1e-3f);

	float alpha2 = roughness * roughness;
	float3 hlf = importance_sample_ggx((float2)(get_random(seed0, seed1), get_random(seed0, seed1)), &ray->tf, alpha2);
	float3 new_dir = reflect(ray->dir, hlf);

	if (dot(ray->normal, new_dir) < 0.0f) {
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
*/
#endif

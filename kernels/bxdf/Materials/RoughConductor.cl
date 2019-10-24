#if defined(ROUGH_COND) && !defined(__ROUGH_CONDUCTOR__)
#define __ROUGH_CONDUCTOR__

bool RoughConductorBSDF(
	Ray* ray, SurfaceScatterEvent* event,
	const Material* mat,
	RNG_SEED_PARAM
) {
	float alpha = roughnessToAlpha(mat->dist, mat->roughness);

	float3 m = Microfacet_sample(mat->dist, alpha, next2D(RNG_SEED_VALUE));
	float wiDotM = dot(event->wi, m);
	event->wo = 2.0f * wiDotM * m - event->wi;
	if (wiDotM <= 0.0f || event->wo.z <= 0.0f)
		return false;


	float G = Microfacet_G(mat->dist, alpha, event->wi, event->wo, m);
	float D = Microfacet_D(mat->dist, alpha, m);
	float mPdf = Microfacet_pdf(mat->dist, alpha, m);
	float pdf = mPdf * 0.25f / wiDotM;
	float weight = wiDotM * G * D / (event->wi.z * mPdf);

	float3 F = conductorReflectance3(mat->eta, mat->k, wiDotM);

	event->pdf = pdf;
	event->weight = mat->color * F * weight;
	event->sampledLobe = GlossyReflectionLobe;

	return true;
}

float3 RoughConductorBSDF_eval(const SurfaceScatterEvent* event, const Material* mat){
	float alpha = roughnessToAlpha(mat->dist, mat->roughness);

	float3 hr = normalize(event->wi + event->wo);
	float cosThetaM = dot(event->wi, hr);

	float3 F = conductorReflectance3(mat->eta, mat->k, cosThetaM);

	float G = Microfacet_G(mat->dist, alpha, event->wi, event->wo, hr);
	float D = Microfacet_D(mat->dist, alpha, hr);
	float fr = (G * D * 0.25f) / event->wi.z;

	return mat->albedo * (F * fr);
}

float RoughConductorBSDF_pdf(const SurfaceScatterEvent* event, const Material* mat){
	float sampleAlpha = roughnessToAlpha(mat->dist, mat->roughness);

	float3 hr = normalize(event->wi + event->wo);
	return Microfacet_pdf(mat->dist, sampleAlpha, hr) * 0.25f / dot(event->wi, hr);
}

#endif

#if (defined(ROUGH_COND) || defined(COAT)) && !defined(__ROUGH_CONDUCTOR__)
#define __ROUGH_CONDUCTOR__

bool RoughConductorBSDF(
	const Ray* ray, SurfaceScatterEvent* event,
	const Material* mat,
	RNG_SEED_PARAM
) {
	if (event->wi.z <= 0.0f)
		return false;

	float alpha = roughnessToAlpha(mat->dist, mat->roughness);

	float3 m;
	if (mat->dist & GGX)
		m = Microfacet_sampleVNDF_GGX(event->wi, alpha, next2D(RNG_SEED_VALUE));
	else
		m = Microfacet_sample(mat->dist, alpha, next2D(RNG_SEED_VALUE));

	float wiDotM = dot(event->wi, m);
	event->wo = 2.0f * wiDotM * m - event->wi;
	if (wiDotM <= 0.0f || event->wo.z <= 0.0f)
		return false;

	float3 F = conductorReflectance3(mat->eta, mat->k, wiDotM);

	float pdf, weightFactor;
	if (mat->dist & GGX) {
		float G1_wi = Microfacet_G1(GGX, alpha, event->wi, m);
		float G1_wo = Microfacet_G1(GGX, alpha, event->wo, m);
		float D     = Microfacet_D(GGX, alpha, m);
		pdf          = G1_wi * D / (4.0f * event->wi.z);
		weightFactor = G1_wo;
	} else {
		float G    = Microfacet_G(mat->dist, alpha, event->wi, event->wo, m);
		float D    = Microfacet_D(mat->dist, alpha, m);
		float mPdf = Microfacet_pdf(mat->dist, alpha, m);
		pdf          = mPdf * 0.25f / wiDotM;
		weightFactor = wiDotM * G * D / (event->wi.z * mPdf);
	}

	event->pdf    = pdf;
	event->weight = mat->color * F * weightFactor;
	event->sampledLobe = GlossyReflectionLobe;

	return true;
}

float3 RoughConductorBSDF_eval(const SurfaceScatterEvent* event, const Material* mat){
	if (event->wi.z <= 0.0f || event->wo.z <= 0.0f)
		return (float3)(0.0f);

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
	if (event->wi.z <= 0.0f || event->wo.z <= 0.0f)
		return 0.0f;

	float sampleAlpha = roughnessToAlpha(mat->dist, mat->roughness);
	float3 hr = normalize(event->wi + event->wo);
	float wiDotHr = dot(event->wi, hr);

	if (mat->dist & GGX)
		return Microfacet_pdfVNDF_GGX(sampleAlpha, event->wi, hr);
	else
		return Microfacet_pdf(mat->dist, sampleAlpha, hr) * 0.25f / wiDotHr;
}

#endif

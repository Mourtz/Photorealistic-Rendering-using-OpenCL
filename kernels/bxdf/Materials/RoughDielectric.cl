#if !defined(__ROUGH_DIELECTRIC__)
#define __ROUGH_DIELECTRIC__

bool RoughDielectricBSDF(
	const Ray* ray, SurfaceScatterEvent* event,
	const Material* mat,
	RNG_SEED_PARAM
) {
	const float wiDotN = event->wi.z;

	const float eta = event->wi.z < 0.0f ? mat->ior.x : 1.0f / mat->ior.x;

	float sampleRoughness = (1.2f - 0.2f * native_sqrt(fabs(wiDotN))) * mat->roughness;
	float alpha = roughnessToAlpha(mat->dist, mat->roughness);
	float sampleAlpha = roughnessToAlpha(mat->dist, sampleRoughness);

	float3 m = Microfacet_sample(mat->dist, sampleAlpha, next2D(RNG_SEED_VALUE));
	float pm = Microfacet_pdf(mat->dist, sampleAlpha, m);

	if (pm < 1e-10f)
		return false;

	float wiDotM = dot(event->wi, m);
	float cosThetaT = 0.0f;
	float F = dielectricReflectance(1.0f / mat->ior.x, wiDotM, &cosThetaT);
	float etaM = wiDotM < 0.0f ? mat->ior.x : 1.0f / mat->ior.x;

	bool reflect = next1D(RNG_SEED_VALUE) < F;

	if (reflect)
		event->wo = 2.0f * wiDotM * m - event->wi;
	else
		event->wo = (etaM * wiDotM - sgnE(wiDotM) * cosThetaT) * m - etaM * event->wi;

	float woDotN = event->wo.z;

	bool reflected = wiDotN * woDotN > 0.0f;
	if (reflected != reflect)
		return false;

	float woDotM = dot(event->wo, m);
	float G = Microfacet_G(mat->dist, alpha, event->wi, event->wo, m);
	float D = Microfacet_D(mat->dist, alpha, m);
	event->weight = (float3)(fabs(wiDotM) * G * D / (fabs(wiDotN) * pm));

	if (reflect) {
		event->pdf = F * pm * 0.25f / fabs(wiDotM);
		event->sampledLobe = GlossyReflectionLobe;
	}
	else {
		event->pdf = (1.0f - F) * pm * fabs(woDotM) / pow(eta * wiDotM + woDotM, 2.0f);
		event->sampledLobe = GlossyTransmissionLobe;
	}

	const bool ABS1 = mat->t & ABS_REFR, ABS2 = mat->t & ABS_REFR2;
	if (ABS1 | ABS2) {
		event->weight *= ABS2 ? mat->color : 1.0f;
		event->weight *= ray->backside ? exp(-ray->t * ((ABS1) ? mat->color : 1.0f) * 10.0f) : 1.0f;
	}
	else {
		event->weight *= mat->albedo;
	}

	return true;
}

float3 RoughDielectricBSDF_eval(const SurfaceScatterEvent* event, const Material* mat) {
	float wiDotN = event->wi.z;
	float woDotN = event->wo.z;

	bool reflect = wiDotN * woDotN >= 0.0f;

	float alpha = roughnessToAlpha(mat->dist, mat->roughness);

	const float eta = wiDotN < 0.0f ? mat->ior.x : 1.0f / mat->ior.x;
	float3 m;
	if (reflect)
		m = sgnE(wiDotN) * normalize(event->wi + event->wo);
	else
		m = -normalize(event->wi * eta + event->wo);

	float wiDotM = dot(event->wi, m);
	float woDotM = dot(event->wo, m);

	float cosThetaT = 0.0f;
	float F = dielectricReflectance(1.0f / mat->ior.x, wiDotM, &cosThetaT);
	float G = Microfacet_G(mat->dist, alpha, event->wi, event->wo, m);
	float D = Microfacet_D(mat->dist, alpha, m);

	float fx;
	if (reflect) {
		fx = (F * G * D * 0.25f) / fabs(wiDotN);
	}
	else {
		fx = fabs(wiDotM * woDotM) * (1.0f - F) * G * D / (pow(eta * wiDotM + woDotM, 2.0f) * fabs(wiDotN));
	}
	
	return mat->albedo*fx;
}

float RoughDielectricBSDF_pdf(const SurfaceScatterEvent* event, const Material* mat) {
	float wiDotN = event->wi.z;
	float woDotN = event->wo.z;

	bool reflect = wiDotN * woDotN >= 0.0f;

	float sampleRoughness = (1.2f - 0.2f * native_sqrt(fabs(wiDotN))) * mat->roughness;
	float sampleAlpha = roughnessToAlpha(mat->dist, sampleRoughness);

	float eta = wiDotN < 0.0f ? mat->ior.x : 1.0f / mat->ior.x;
	float3 m;
	if (reflect)
		m = sgnE(wiDotN) * normalize(event->wi + event->wo);
	else
		m = -normalize(event->wi * eta + event->wo);

	float wiDotM = dot(event->wi, m);
	float woDotM = dot(event->wo, m);
	float cosThetaT = 0.0f;
	float F = dielectricReflectance(1.0f / mat->ior.x, wiDotM, &cosThetaT);
	float pm = Microfacet_pdf(mat->dist, sampleAlpha, m);

	float pdf;
	if (reflect)
		pdf = F * pm * 0.25f / fabs(wiDotM);
	else
		pdf = (1.0f - F) * pm * fabs(woDotM) / pow(eta * wiDotM + woDotM, 2.0f);

	return pdf;
}

inline float RoughDielectricBSDF_eta(const SurfaceScatterEvent* event, const Material* mat){
	if (event->wi.z * event->wo.z >= 0.0f)
		return 1.0f;
	else
		return event->wi.z < 0.0f ? mat->ior.x : 1.0f/mat->ior.x;
}

#endif

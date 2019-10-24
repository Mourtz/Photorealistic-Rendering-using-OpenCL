#if defined(DIEL) && !defined(__DIELECTRIC__)
#define __DIELECTRIC__

bool DielectricBSDF(
	const Ray* ray, SurfaceScatterEvent* event,
	const Material* mat,
	RNG_SEED_PARAM
) {
	const float eta = event->wi.z < 0.0f ? mat->ior.x : 1.0f / mat->ior.x;

	float cosThetaT = 0.0f;
	float F = dielectricReflectance(eta, fabs(event->wi.z), &cosThetaT);

	if (next1D(RNG_SEED_VALUE) < F) {
		event->wo = (float3)(-event->wi.x, -event->wi.y, event->wi.z);
		event->pdf = F;
		event->sampledLobe = SpecularReflectionLobe;
		event->weight = (float3)(F);
	}
	else {
		if (F == 1.0f)
			return false;

		event->wo = (float3)(-event->wi.x * eta, -event->wi.y * eta, -copysign(cosThetaT, event->wi.z));
		event->pdf = 1.0f - F;
		event->sampledLobe = SpecularTransmissionLobe;
		event->weight = (float3)(1.0f - F);
	}

	const bool ABS1 = mat->t & ABS_REFR, ABS2 = mat->t & ABS_REFR2;
	if (ABS1 | ABS2) {
		event->weight *= ABS2 ? mat->color : 1.0f;
		event->weight *= ray->backside ? exp(-ray->t * ((ABS1) ? mat->color : 1.0f) * 10.0f) : 1.0f;
	}
	else {
		event->weight *= mat->color;
	}

	return true;
}

float3 DielectricBSDF_eval(const SurfaceScatterEvent* event, const Material* mat){
	const float eta = event->wi.z < 0.0f ? mat->ior.x : 1.0f / mat->ior.x;

	float cosThetaT = 0.0f;
	float F = dielectricReflectance(eta, fabs(event->wi.z), &cosThetaT);

	if (event->wi.z * event->wo.z >= 0.0f) {
		if (checkReflectionConstraint(&event->wi, &event->wo))
			return F * mat->albedo;
		else
			return (float3)(0.0f);
	}
	else {
		if (checkRefractionConstraint(&event->wi, &event->wo, eta, cosThetaT))
			return (1.0f - F) * mat->albedo;
		else
			return (float3)(0.0f);
	}
}

float DielectricBSDF_pdf(const SurfaceScatterEvent* event, const Material* mat){
	const float eta = event->wi.z < 0.0f ? mat->ior.x : 1.0f / mat->ior.x;

	float cosThetaT = 0.0f;
	float F = dielectricReflectance(eta, fabs(event->wi.z), &cosThetaT);

	if (event->wi.z * event->wo.z >= 0.0f) {
		if (checkReflectionConstraint(&event->wi, &event->wo))
			return F;
		else
			return 0.0f;
	}
	else {
		if (checkRefractionConstraint(&event->wi, &event->wo, eta, cosThetaT))
			return 1.0f - F;
		else
			return 0.0f;
	}
}

inline float DielectricBSDF_eta(const SurfaceScatterEvent* event, const Material* mat){
	if (event->wi.z * event->wo.z >= 0.0f)
		return 1.0f;
	else
		return event->wi.z < 0.0f ? mat->ior.x : 1.0f / mat->ior.x;
}

#endif

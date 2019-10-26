#if defined(COND) && !defined(__CONDUCTOR__)
#define __CONDUCTOR__

bool ConductorBSDF(
	Ray* ray, SurfaceScatterEvent* event,
	const Material* mat,
	RNG_SEED_PARAM
) {
	// Silver (Ag) 
	const float F = conductorReflectance(0.051585f, 3.9046f, event->wi.z);

	event->wo = (float3)(-event->wi.x, -event->wi.y, event->wi.z);
	event->pdf = 1.0f;
	event->weight = mat->albedo * F;
	event->sampledLobe = SpecularReflectionLobe;
	return true;
}

float3 ConductorBSDF_eval(const SurfaceScatterEvent* event, const Material* mat) {
	// Silver (Ag) 
	const float F = conductorReflectance(0.051585f, 3.9046f, event->wi.z);

	if (checkReflectionConstraint(&event->wi, &event->wo))
		return mat->color * F;
	else
		return (float3)(0.0f);
}

float ConductorBSDF_pdf(const SurfaceScatterEvent* event) {
	return (float)(checkReflectionConstraint(&event->wi, &event->wo));
}

#endif

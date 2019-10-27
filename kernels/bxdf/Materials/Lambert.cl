#if defined(DIFF) && !defined(__LAMBERT__)
#define __LAMBERT__

bool LambertBSDF(
	const Ray* ray, SurfaceScatterEvent* event,
	const Material* mat,
	RNG_SEED_PARAM
) {
	event->wo = cosineHemisphere(next2D(RNG_SEED_VALUE));
	event->pdf = cosineHemispherePdf(event->wo);
	event->weight = mat->albedo;
	event->sampledLobe = DiffuseReflectionLobe;
	return true;
}

float3 LambertBSDF_eval(const SurfaceScatterEvent* event, const Material* mat) {
	return mat->albedo * INV_PI * event->wo.z;
}

float LambertBSDF_pdf(const SurfaceScatterEvent* event) {
	cosineHemispherePdf(event->wo);
}

#endif
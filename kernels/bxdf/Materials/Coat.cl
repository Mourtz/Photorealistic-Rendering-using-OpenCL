#if defined(COAT) && !defined(__COAT__)
#define __COAT__

#define _ior				1.3f
#define _thickness			1.0f
#define _sigmaA				0.0f
#define _scaledSigmaA		_thickness*_sigmaA
#define _avgTransmittance	native_exp(-2.0f*_scaledSigmaA)

bool CoatBSDF(
	const Ray* ray, SurfaceScatterEvent* event,
	const Material* mat,
	RNG_SEED_PARAM
){
	const float eta = 1.0f / _ior;

	float cosThetaTi;
	float Fi = dielectricReflectance(eta, event->wi.z, &cosThetaTi);

	float specularProbability = Fi / (Fi + _avgTransmittance * (1.0f - Fi));

	if (nextBoolean(specularProbability, RNG_SEED_VALUE)) {
		event->wo = (float3)(-event->wi.x, -event->wi.y, event->wi.z);
		event->pdf = specularProbability;
		event->weight = (float3)(Fi / specularProbability);
		event->sampledLobe = SpecularReflectionLobe;
	}
	else {
		float3 originalWi = event->wi;
		float3 wiSubstrate = (float3)(originalWi.x * eta, originalWi.y * eta, cosThetaTi);
		event->wi = wiSubstrate;
		if (!RoughConductorBSDF(ray, event, mat, RNG_SEED_VALUE))
			return false;

		event->wi = originalWi;

		float cosThetaTo;
		float Fo = dielectricReflectance(_ior, event->wo.z, &cosThetaTo);
		if (Fo == 1.0f)
			return false;
		float cosThetaSubstrate = event->wo.z;
		event->wo = (float3)(event->wo.x * _ior, event->wo.y * _ior, cosThetaTo);
		event->weight *= (1.0f - Fi) * (1.0f - Fo);
		if (_scaledSigmaA > 0.0f)
			event->weight *= native_exp(_scaledSigmaA * (-1.0f / cosThetaSubstrate - 1.0f / cosThetaTi));

		event->weight /= 1.0f - specularProbability;
		event->pdf *= 1.0f - specularProbability;
		event->pdf *= eta * eta * cosThetaTo / cosThetaSubstrate;
	}

	return true;
}

float3 CoatBSDF_eval(const SurfaceScatterEvent* event, const Material* mat) {
	const float eta = 1.0f / _ior;

	float cosThetaTi;
	float Fi = dielectricReflectance(eta, event->wi.z, &cosThetaTi);

	if (checkReflectionConstraint(&event->wi, &event->wo)) {
		return (float3)(Fi);
	}
	else {
		float cosThetaTo;
		float Fo = dielectricReflectance(eta, event->wo.z, &cosThetaTo);

		SurfaceScatterEvent nE = *event;
		nE.wi = (float3)(event->wi.x * eta, event->wi.y * eta, copysign(cosThetaTi, event->wi.z));
		nE.wo = (float3)(event->wo.x * eta, event->wo.y * eta, copysign(cosThetaTo, event->wo.z));
		float3 substrateF = RoughConductorBSDF_eval(&nE, mat);

		if (_scaledSigmaA > 0.0f)
			substrateF *= native_exp(_scaledSigmaA * (-1.0f / cosThetaTo - 1.0f / cosThetaTi));

		float laplacian = eta * eta * event->wo.z / cosThetaTo;

		return laplacian * (1.0f - Fi) * (1.0f - Fo) * substrateF;
	}
}

float CoatBSDF_pdf(const SurfaceScatterEvent* event, const Material* mat) {
	const float eta = 1.0f / _ior;

	float cosThetaTi;
	float Fi = dielectricReflectance(eta, event->wi.z, &cosThetaTi);

	float specularProbability = Fi / (Fi + _avgTransmittance * (1.0f - Fi));

	if (checkReflectionConstraint(&event->wi, &event->wo))
		return specularProbability;
	else {
		float cosThetaTo;
		dielectricReflectance(eta, event->wo.z, &cosThetaTo);

		SurfaceScatterEvent nE = *event;
		nE.wi = (float3)(event->wi.x * eta, event->wi.y * eta, copysign(cosThetaTi, event->wi.z));
		nE.wo = (float3)(event->wo.x * eta, event->wo.y * eta, copysign(cosThetaTo, event->wo.z));

		return RoughConductorBSDF_pdf(&nE, mat)
			* (1.0f - specularProbability) * eta * eta * fabs(event->wo.z / cosThetaTo);
	}
}

#undef _ior
#undef _thickness
#undef _sigmaA
#undef _scaledSigmaA
#undef _avgTransmittance

#endif

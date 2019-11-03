#ifndef __ISOTROPIC_PHASE__
#define __ISOTROPIC_PHASE__

//--------------------- IsotropicPhaseFunction -----------------------

inline float3 phase_eval(const float3 wi, const float3 wo) {
	return (float3)(INV_FOUR_PI);
}

inline float phase_pdf(const float3 wi, const float3 wo) {
	return INV_FOUR_PI;
}

bool phase_sample(
	const float3 wi, PhaseSample* phaseSample,
	RNG_SEED_PARAM
) {

	phaseSample->w = uniformSphere(next2D(RNG_SEED_VALUE));
	phaseSample->weight = (float3)(1.0f);
	phaseSample->pdf = INV_FOUR_PI;

	return true;
}

#endif

#ifndef __ISOTROPIC_PHASE__
#define __ISOTROPIC_PHASE__

//--------------------- IsotropicPhaseFunction -----------------------

inline float3 iso_eval() {
	return (float3)(INV_FOUR_PI);
}

inline float iso_pdf() {
	return INV_FOUR_PI;
}

bool iso_sample(
	const float3 wi, PhaseSample* sample,
	RNG_SEED_PARAM
) {

	sample->w = uniformSphere(next2D(RNG_SEED_VALUE));
	sample->weight = 1.0f;
	sample->pdf = INV_FOUR_PI;

	return true;
}

#endif

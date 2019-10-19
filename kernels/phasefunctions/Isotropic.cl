//--------------------- IsotropicPhaseFunction -----------------------

float3 iso_eval() {
	return (float3)(INV_FOUR_PI);
}

float iso_pdf() {
	return INV_FOUR_PI;
}

bool iso_sample(
	const float3 wi, PhaseSample* sample,
	RNG_SEED_PARAM
) {

	float2 xi = (float2)(next1D(RNG_SEED_VALUE), next1D(RNG_SEED_VALUE));
	sample->w = uniformSphere(xi);
	sample->weight = 1.0f;
	sample->pdf = INV_FOUR_PI;

	return true;
}
//--------------------- IsotropicPhaseFunction -----------------------

float3 iso_eval() {
	return (float3)(INV_FOUR_PI);
}

float iso_pdf() {
	return INV_FOUR_PI;
}

bool iso_sample(
	const float3 wi, PhaseSample* sample,
	RNG_SEED_TYPE
) {

	float2 xi = (float2)(get_random(RNG_SEED_NAME), get_random(RNG_SEED_NAME));
	sample->w = uniformSphere(xi);
	sample->weight = 1.0f;
	sample->pdf = INV_FOUR_PI;

	return true;
}
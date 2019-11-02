#ifndef __HG__
#define __HG__

#define _g 1.0f

//--------------------- HenyeyGreensteinPhaseFunction -----------------------

float hg(const float cosTheta) {
    float term = 1.0f + _g*_g - 2.0f*_g*cosTheta;
    return INV_FOUR_PI*(1.0f - _g*_g)/(term*native_sqrt(term));
}

float3 hg_eval(const float3 wi, const float3 wo) {
	return (float3)(hg(dot(wi, wo)));
}

float hg_pdf(const float3 wi, const float3 wo) {
	return hg(dot(wi, wo));
}

bool hg_sample(
	const float3 wi, PhaseSample* sample,
	RNG_SEED_PARAM
) {

	float2 xi = (float2)(next1D(RNG_SEED_VALUE), next1D(RNG_SEED_VALUE));
	if (_g == 0.0f) {
		sample->w = uniformSphere(xi);
		sample->pdf = uniformSpherePdf();
	}
	else {
		float phi = xi.x*TWO_PI;
		float cosTheta = (1.0f + _g * _g - pow((1.0f - _g * _g) / (1.0f + _g * (xi.y*2.0f - 1.0f)), 2.0f)) / (2.0f*_g);
		float sinTheta = sqrt(fmax(1.0f - cosTheta * cosTheta, 0.0f));

		TangentFrame tf = createTangentFrame(&wi);
		sample->w = toGlobal(&tf, (float3)(
			native_cos(phi)*sinTheta,
			native_sin(phi)*sinTheta,
			cosTheta
		));

		sample->pdf = hg(cosTheta);
	}
	sample->weight = 1.0f;

	return true;
}

#undef _g

#endif

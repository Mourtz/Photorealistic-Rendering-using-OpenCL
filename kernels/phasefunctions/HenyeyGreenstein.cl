#ifndef __HG__
#define __HG__

#define _g 0.6f

//--------------------- HenyeyGreensteinPhaseFunction -----------------------

float hg(const float cosTheta) {
    float term = 1.0f + _g*_g - 2.0f*_g*cosTheta;
    return INV_FOUR_PI*(1.0f - _g*_g)/(term*native_sqrt(term));
}

float3 phase_eval(const float3 wi, const float3 wo) {
	return (float3)(hg(dot(wi, wo)));
}

float phase_pdf(const float3 wi, const float3 wo) {
	return hg(dot(wi, wo));
}

bool phase_sample(
	const float3 wi, PhaseSample* phaseSample,
	RNG_SEED_PARAM
) {

	float2 xi = next2D(RNG_SEED_VALUE);
	if (_g == 0.0f) {
		phaseSample->w = uniformSphere(xi);
		phaseSample->pdf = uniformSpherePdf();
	}
	else {
		float phi = xi.x*TWO_PI;
		float cosTheta = (1.0f + _g * _g - pow((1.0f - _g * _g) / (1.0f + _g * (xi.y*2.0f - 1.0f)), 2.0f)) / (2.0f*_g);
		float sinTheta = native_sqrt(fmax(1.0f - cosTheta * cosTheta, 0.0f));

		TangentFrame tf = createTangentFrame(&wi);
		phaseSample->w = toGlobal(&tf, (float3)(
			native_cos(phi)*sinTheta,
			native_sin(phi)*sinTheta,
			cosTheta
		));

		phaseSample->pdf = hg(cosTheta);
	}
	phaseSample->weight = (float3)(1.0f);

	return true;
}

#undef _g

#endif

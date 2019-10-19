#ifndef __HG__
#define __HG__

//--------------------- HenyeyGreensteinPhaseFunction -----------------------

float hg(const float cosTheta, const float _g) {
    float term = 1.0f + _g*_g - 2.0f*_g*cosTheta;
    return INV_FOUR_PI*(1.0f - _g*_g)/(term*native_sqrt(term));
}

float3 hg_eval(const float3 wi, const float3 wo, const float _g) {
	return (float3)(hg(dot(wi, wo), _g));
}

float hg_pdf(const float3 wi, const float3 wo, const float _g) {
	return hg(dot(wi, wo), _g);
}

void hg_sample_fast(float3* dir, const float _g, float2* xi) {
	float phi = xi->x*TWO_PI;
	float cosTheta = (1.0f + _g * _g - pow((1.0f - _g * _g) / (1.0f + _g * (xi->y*2.0f - 1.0f)), 2.0f)) / (2.0f*_g);
	float sinTheta = native_sqrt(fmax(1.0f - cosTheta * cosTheta, 0.0f));

	TangentFrame tf = createTangentFrame(dir);
	*dir = toGlobal(&tf, (float3)(
		native_cos(phi)*sinTheta,
		native_sin(phi)*sinTheta,
		cosTheta
	));
}

bool hg_sample(
	const float3 wi, const float _g, PhaseSample* sample,
	RNG_SEED_PARAM
) {

	float2 xi = (float2)(get_random(RNG_SEED_VALUE), get_random(RNG_SEED_VALUE));
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

		sample->pdf = hg(cosTheta, _g);
	}
	sample->weight = 1.0f;

	return true;
}

#endif

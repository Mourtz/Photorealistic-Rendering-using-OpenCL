#ifndef __HG__
#define __HG__

//--------------------- HenyeyGreensteinPhaseFunction -----------------------

float hg(const float cosTheta, const float _g) {
	float term = 1.0f + _g * _g - 2.0f*_g*cosTheta;
	return INV_FOUR_PI * (1.0f - _g * _g) / (term*sqrt(term));
}

float3 hg_eval(const float3 wi, const float3 wo, const float _g) {
	return (float3)(hg(dot(wi, wo), _g));
}

float hg_pdf(const float3 wi, const float3 wo, const float _g) {
	return hg(dot(wi, wo), _g);
}

void hg_sample_fast(float3* dir, const float _g, uint* seed0, uint* seed1) {
	float phi = get_random(seed0, seed1)*TWO_PI;
	float cosTheta = (1.0f + _g * _g - pow((1.0f - _g * _g) / (1.0f + _g * (get_random(seed0, seed1)*2.0f - 1.0f)), 2.0f)) / (2.0f*_g);
	float sinTheta = native_sqrt(fmax(1.0f - cosTheta * cosTheta, 0.0f));

	float3 u, v;
	calc_binormals(*dir, &u, &v);
	*dir =
		u * native_cos(phi)*sinTheta +
		v * native_sin(phi)*sinTheta +
		(*dir) * cosTheta;
}

bool hg_sample(
	const float3 wi, const float _g, PhaseSample* sample,
	uint* seed0, uint* seed1
) {

	float2 xi = (float2)(get_random(seed0, seed1), get_random(seed0, seed1));
	if (_g == 0.0f) {
		sample->w = uniformSphere(xi);
		sample->weight = 1.0f;
		sample->pdf = INV_FOUR_PI;
	}
	else {
		float phi = xi.x*TWO_PI;
		float cosTheta = (1.0f + _g * _g - pow((1.0f - _g * _g) / (1.0f + _g * (xi.y*2.0f - 1.0f)), 2.0f)) / (2.0f*_g);
		float sinTheta = sqrt(fmax(1.0f - cosTheta * cosTheta, 0.0f));

		float3 u, v;
		calc_binormals(wi, &u, &v);
		sample->w =
			u * cos(phi)*sinTheta +
			v * sin(phi)*sinTheta +
			wi * cosTheta;

		sample->weight = 1.0f;
		sample->pdf = hg(cosTheta, _g);
	}

	return true;
}

#endif

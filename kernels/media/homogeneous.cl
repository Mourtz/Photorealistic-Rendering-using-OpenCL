#ifndef __HOMOGENEOUS_MEDIUM__
#define __HOMOGENEOUS_MEDIUM__

#define _sigmaA			medium->sigmaA
#define _sigmaS			medium->sigmaS
#define _sigmaT			medium->sigmaT
#define _absorptionOnly	medium->absorptionOnly

//------------------------- Homogeneous Medium -------------------------

void HomogeneousMedium_sampleDistance(
	MediumSample* mediumSample,
	const Medium* medium,
	const Ray* ray,
	RNG_SEED_PARAM
) {
	const float maxT = ray->t;

	if (_absorptionOnly) {
		mediumSample->t = maxT;
		mediumSample->weight = native_exp(-mediumSample->t*_sigmaT);
		mediumSample->pdf = 1.0f;
		mediumSample->exited = true;
	}
	else {
		float sigmaTc = ((float*)(&_sigmaT))[(int)(round(next1D(RNG_SEED_VALUE)*3.0f))];

		float t = -native_log(1.0f - next1D(RNG_SEED_VALUE)) / sigmaTc;
		mediumSample->t = fmin(t, maxT);
		mediumSample->continuedT = t;
		mediumSample->exited = (t >= maxT);

		float3 tau = mediumSample->t * _sigmaT;
		float3 continuedTau = mediumSample->continuedT * _sigmaT;

		mediumSample->weight = native_exp(-tau);
		mediumSample->continuedWeight = native_exp(-continuedTau);

		if (mediumSample->exited) {
			mediumSample->pdf = avg3(native_exp(-tau));
		}
		else {
			mediumSample->pdf = avg3(_sigmaT*native_exp(-tau));
			mediumSample->weight *= _sigmaS;
		}
		mediumSample->weight /= mediumSample->pdf;
		mediumSample->continuedWeight = _sigmaS * mediumSample->continuedWeight / avg3(_sigmaT*native_exp(-continuedTau));
	}

	mediumSample->p = ray->origin + ray->dir*mediumSample->t;
}

#undef _sigmaA
#undef _sigmaS
#undef _sigmaT
#undef _absorptionOnly

#endif

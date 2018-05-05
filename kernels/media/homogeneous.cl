#ifndef __HOMOGENEOUS_MEDIUM__
#define __HOMOGENEOUS_MEDIUM__

//------------------------- Homogeneous Medium -------------------------

void sampleDistance(
	const Ray* ray, MediumSample* m_sample,
	const Medium* medium,
	uint* seed0, uint* seed1
) {
	const float maxT = ray->t;

	if (medium->absorptionOnly) {
		m_sample->t = maxT;
		m_sample->weight = native_exp(-medium->sigmaT * maxT);
		m_sample->pdf = 1.0f;
		m_sample->exited = true;
	}
	else {
		const float* sigmaT = &medium->sigmaT;
		float sigmaTc = sigmaT[(int)(round(get_random(seed0, seed1)*3.0f))];

		float t = -native_log(1.0f - get_random(seed0, seed1)) / sigmaTc;
		m_sample->t = fmin(t, maxT);
		m_sample->continuedT = t;
		m_sample->weight = native_exp(-m_sample->t*medium->sigmaT);
		//m_sample->continuedWeight = native_exp(-m_sample->continuedT*medium->sigmaT);
		m_sample->exited = (t >= maxT);
		if (m_sample->exited) {
			m_sample->pdf = avg3(m_sample->weight);
		}
		else {
			m_sample->pdf = avg3(medium->sigmaT*m_sample->weight);
			m_sample->weight *= medium->sigmaS;
		}
		m_sample->weight /= m_sample->pdf;
		//m_sample->continuedWeight = medium->sigmaS * m_sample->continuedWeight / avg3(medium->sigmaT*m_sample->continuedWeight);
	}

	m_sample->p = ray->origin + m_sample->t*ray->dir;
}

#endif

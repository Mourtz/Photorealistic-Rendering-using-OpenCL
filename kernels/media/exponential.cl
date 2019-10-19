#ifndef __EXPONENTIAL_MEDIUM__
#define __EXPONENTIAL_MEDIUM__

#define _falloffScale		1.0f
#define _falloffDirection	F3_UP
#define _unitPoint			0.0f

#define density(x, dx, t) exp(-(x + dx * t))
#define density2(p) exp(-_falloffScale * dot(p - _unitPoint, _falloffDirection))

float densityIntegral(float x, float dx, float tMax){
	if (tMax == INF)
		return exp(-x) / dx;
	else if (dx == 0.0f)
		return exp(-x)*tMax;
	else
		return (exp(-x) - exp(-dx * tMax - x)) / dx;
}


float inverseOpticalDepth(float x, float dx, float sigmaT, float logXi){
	if (dx == 0.0f) {
		float effectiveSigmaTc = sigmaT * exp(-x);
		return -logXi / effectiveSigmaTc;
	}
	else {
		float denom = sigmaT + dx*exp(x)*logXi;
		return denom <= 0.0f ? INF : log(sigmaT / denom) / dx;
	}
}

void sampleDistance(
	const Ray* ray, MediumSample* m_sample,
	const Medium* medium,
	RNG_SEED_TYPE
) {
	float  x = _falloffScale * dot(ray->origin - _unitPoint, _falloffDirection);
	float dx = _falloffScale * dot(ray->dir, _falloffDirection);

	const float maxT = ray->t;
	if (medium->absorptionOnly) {
		m_sample->t = maxT;
		m_sample->weight = exp(-medium->sigmaT * densityIntegral(x, dx, ray->t));
		m_sample->pdf = 1.0f;
		m_sample->exited = true;
	} else {
		const float* sigmaT = &medium->sigmaT;
		float sigmaTc = sigmaT[(int)(round(get_random(RNG_SEED_NAME)*3.0f))];

		float xi = 1.0f - get_random(RNG_SEED_NAME);
		float logXi = log(xi);

		float t = inverseOpticalDepth(x, dx, sigmaTc, logXi);
		m_sample->t = fmin(t, maxT);
		m_sample->weight = exp(-medium->sigmaT * densityIntegral(x, dx, m_sample->t));
		m_sample->exited = (t >= maxT);
		if (m_sample->exited) {
			m_sample->pdf = avg3(m_sample->weight);
		}
		else {
			float rho = density(x, dx, m_sample->t);
			m_sample->pdf = avg3(rho*medium->sigmaT*m_sample->weight);
			m_sample->weight *= rho * medium->sigmaT;
		}
		m_sample->weight /= m_sample->pdf;
	}

	m_sample->p = ray->origin + m_sample->t*ray->dir;
}

#endif
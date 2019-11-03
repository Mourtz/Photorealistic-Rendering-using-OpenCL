#ifndef __FRESNEL__
#define __FRESNEL__

// From "PHYSICALLY BASED LIGHTING CALCULATIONS FOR COMPUTER GRAPHICS" by Peter Shirley
// http://www.cs.virginia.edu/~jdl/bib/globillum/shirley_thesis.pdf
inline float conductorReflectance(float eta, float k, float cosThetaI) {
	float cosThetaISq = cosThetaI * cosThetaI;
	float sinThetaISq = fmax(1.0f - cosThetaISq, 0.0f);
	float sinThetaIQu = sinThetaISq * sinThetaISq;

	float innerTerm = eta * eta - k * k - sinThetaISq;
	float aSqPlusBSq = sqrt(fmax(innerTerm * innerTerm + 4.0f * eta * eta * k * k, 0.0f));
	float a = sqrt(fmax((aSqPlusBSq + innerTerm) * 0.5f, 0.0f));

	float Rs =	((aSqPlusBSq + cosThetaISq) - (2.0f * a * cosThetaI)) /
				((aSqPlusBSq + cosThetaISq) + (2.0f * a * cosThetaI));
	float Rp =	((cosThetaISq * aSqPlusBSq + sinThetaIQu) - (2.0f * a * cosThetaI * sinThetaISq)) /
				((cosThetaISq * aSqPlusBSq + sinThetaIQu) + (2.0f * a * cosThetaI * sinThetaISq));

	return 0.5f * (Rs + Rs * Rp);
}

inline float conductorReflectanceApprox(float eta, float k, float cosThetaI) {
	float cosThetaISq = cosThetaI * cosThetaI;
	float ekSq = eta * eta * +k * k;
	float cosThetaEta2 = cosThetaI * 2.0f * eta;

	float Rp = (ekSq * cosThetaISq - cosThetaEta2 + 1.0f) / (ekSq * cosThetaISq + cosThetaEta2 + 1.0f);
	float Rs = (ekSq - cosThetaEta2 + cosThetaISq) / (ekSq + cosThetaEta2 + cosThetaISq);
	return (Rs + Rp) * 0.5f;
}

inline float3 conductorReflectance3(float3 eta, float3 k, float cosThetaI) {
	return (float3)(
		conductorReflectance(eta.x, k.x, cosThetaI),
		conductorReflectance(eta.y, k.y, cosThetaI),
		conductorReflectance(eta.z, k.z, cosThetaI)
		);
}

inline float dielectricReflectance(float eta, float cosThetaI, float* cosThetaT) {
	if (cosThetaI < 0.0f) {
		eta = 1.0f / eta;
		cosThetaI = -cosThetaI;
	}
	float sinThetaTSq = eta * eta * (1.0f - cosThetaI * cosThetaI);
	if (sinThetaTSq > 1.0f) {
		*cosThetaT = 0.0f;
		return 1.0f;
	}
	*cosThetaT = sqrt(fmax(1.0f - sinThetaTSq, 0.0f));

	float Rs = (eta * ( cosThetaI) - (*cosThetaT)) / (eta * ( cosThetaI) + (*cosThetaT));
	float Rp = (eta * (*cosThetaT) - ( cosThetaI)) / (eta * (*cosThetaT) + ( cosThetaI));

	return (Rs * Rs + Rp * Rp) * 0.5f;
}

inline float3 dielectricReflectance3(float3 eta, float cosThetaI,
	float* cosThetaT_r, float* cosThetaT_g, float* cosThetaT_b
) {
	return (float3)(
		dielectricReflectance(eta.x, cosThetaI, cosThetaT_r),
		dielectricReflectance(eta.y, cosThetaI, cosThetaT_g),
		dielectricReflectance(eta.z, cosThetaI, cosThetaT_b)
	);
}

#endif

#if 0 
/* Schlick's approximation of Fresnel equation */
float schlick(const float3 dir, const float3 n, const float nc, const float nt) {
	float R0 = pow((nc - nt) / (nc + nt), 2.0f);
	return R0 + (1.0f - R0) * pow(1.0f + dot(n, dir), 5.0f);
}

/* Full Fresnel equation */
float fresnel(const float3 dir, const float3 n, const float nc, const float nt, const float3 refr) {
	float cosI = dot(dir, n);
	float costT = dot(n, refr);

	float Rs = pow((nc * cosI - nt * costT) / (nc * cosI + nt * costT), 2.0f);
	float Rp = pow((nc * costT - nt * cosI) / (nc * costT + nt * cosI), 2.0f);
	return (Rs + Rp) * 0.5f;
}

float3 refract(const float3 dir, const float3 nl, const float eta) {
	float k = 1.0f - eta * eta * (1.0f - dot(nl, dir) * dot(nl, dir));

	if (k < 0.0f)
		return (float3)(0.0f);
	else
		return eta * dir - (eta * dot(nl, dir) + sqrt(k)) * nl;
}
#endif
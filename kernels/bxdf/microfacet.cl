#ifndef __MICROFACET__
#define __MICROFACET__

/*Taken from https://github.com/tunabrain/tungsten/blob/master/src/core/bsdfs/Microfacet.hpp */

#define GGX			1<<0
#define BECKMANN	1<<1
#define BLINN		1<<2
#define PHONG		1<<3

#define sqr(t) pow(t, 2.0f)

float D(int dist, float alpha, const float3 m){
	if (m.z <= 0.0f)
		return 0.0f;

	if (dist & GGX) {
		float alphaSq = alpha * alpha;
		float cosThetaSq = m.z*m.z;
		float tanThetaSq = fmax(1.0f - cosThetaSq, 0.0f) / cosThetaSq;
		float cosThetaQu = cosThetaSq * cosThetaSq;
		return alphaSq * INV_PI / (cosThetaQu*sqr(alphaSq + tanThetaSq));
	}

	return 0.0f;
}

float G1(int dist, float alpha, const float3 v, const float3 m) {
	if (dot(v,m)*v.z <= 0.0f)
		return 0.0f;

	if (dist & GGX) {
		float alphaSq = alpha * alpha;
		float cosThetaSq = v.z*v.z;
		float tanThetaSq = fmax(1.0f - cosThetaSq, 0.0f) / cosThetaSq;
		return 2.0f / (1.0f + sqrt(1.0f + alphaSq * tanThetaSq));
	}

	return 0.0f;
}

float G(int dist, float alpha, const float3 i, const float3 o, const float3 m) {
	return G1(dist, alpha, i, m)*G1(dist, alpha, o, m);
}

float pdf(int dist, float alpha, const float3 m){
	return D(dist, alpha, m)*m.z;
}

float3 SampleMicrofacet(int dist, float alpha, float2 xi) {
	float phi = xi.y*TWO_PI;
	float cosTheta = 0.0f;

	if (dist & GGX) {
		float tanThetaSq = alpha * alpha*xi.x / (1.0f - xi.x);
		cosTheta = 1.0f / sqrt(1.0f + tanThetaSq);
	}

	float r = sqrt(fmax(1.0f - cosTheta * cosTheta, 0.0f));
	return (float3)(cos(phi)*r, sin(phi)*r, cosTheta);
}


#undef sqr

#endif
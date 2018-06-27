#ifndef __MICROFACET__
#define __MICROFACET__

/*Taken from https://github.com/tunabrain/tungsten/blob/master/src/core/bsdfs/Microfacet.hpp */

#define BECKMANN	1 << 0
#define PHONG		1 << 1
#define GGX			1 << 2
#define BLINN		1 << 3

float roughnessToAlpha(int dist, float roughness){
    roughness = fmax(roughness, 1e-3f);

    if (dist & PHONG)
        return 2.0f / (roughness * roughness) - 2.0f;
	else
		return roughness;
}

float Microfacet_D(int dist, float alpha, const float3 m)
{
    if (m.z <= 0.0f)
        return 0.0f;

    if (dist & BECKMANN) {
        float alphaSq = alpha * alpha;
        float cosThetaSq = m.z * m.z;
        float tanThetaSq = fmax(1.0f - cosThetaSq, 0.0f) / cosThetaSq;
        float cosThetaQu = cosThetaSq * cosThetaSq;
        return INV_PI * native_exp(-tanThetaSq / alphaSq) / (alphaSq * cosThetaQu);
    }
    else if (dist & PHONG) {
        return (alpha + 2.0f) * INV_TWO_PI * pow(m.z, alpha);
    }
    else if (dist & GGX) {
        float alphaSq = alpha * alpha;
        float cosThetaSq = m.z * m.z;
        float tanThetaSq = fmax(1.0f - cosThetaSq, 0.0f) / cosThetaSq;
        float cosThetaQu = cosThetaSq * cosThetaSq;
        return alphaSq * INV_PI / (cosThetaQu * pow(alphaSq + tanThetaSq, 2.0f));
    }

    return 0.0f;
}

float Microfacet_G1(int dist, float alpha, const float3 v, const float3 m)
{
    if (dot(v, m) * v.z <= 0.0f)
        return 0.0f;

    if (dist & BECKMANN) {
        float cosThetaSq = v.z * v.z;
        float tanTheta = fabs(native_sqrt(fmax(1.0f - cosThetaSq, 0.0f)) / v.z);
        float a = 1.0f / (alpha * tanTheta);
        if (a < 1.6f)
            return (3.535f * a + 2.181f * a * a) / (1.0f + 2.276f * a + 2.577f * a * a);
        else
            return 1.0f;
    }
    else if (dist & PHONG) {
        float cosThetaSq = v.z * v.z;
        float tanTheta = fabs(native_sqrt(fmax(1.0f - cosThetaSq, 0.0f)) / v.z);
        float a = native_sqrt(0.5f * alpha + 1.0f) / tanTheta;
        if (a < 1.6f)
            return (3.535f * a + 2.181f * a * a) / (1.0f + 2.276f * a + 2.577f * a * a);
        else
            return 1.0f;
    }
    else if (dist & GGX) {
        float alphaSq = alpha * alpha;
        float cosThetaSq = v.z * v.z;
        float tanThetaSq = fmax(1.0f - cosThetaSq, 0.0f) / cosThetaSq;
        return 2.0f / (1.0f + native_sqrt(1.0f + alphaSq * tanThetaSq));
    }

    return 0.0f;
}

float Microfacet_G(int dist, float alpha, const float3 i, const float3 o, const float3 m)
{
    return Microfacet_G1(dist, alpha, i, m) * Microfacet_G1(dist, alpha, o, m);
}

float Microfacet_pdf(int dist, float alpha, const float3 m)
{
    return Microfacet_D(dist, alpha, m) * m.z;
}

float3 Microfacet_sample(int dist, float alpha, float2 xi)
{
    float phi = xi.y * TWO_PI;
    float cosTheta = 0.0f;

    if (dist & BECKMANN) {
        float tanThetaSq = -alpha * alpha * native_log(1.0f - xi.x);
        cosTheta = 1.0f / native_sqrt(1.0f + tanThetaSq);
    }
    else if (dist & PHONG) {
        cosTheta = pow(xi.x, 1.0f / (alpha + 2.0f));
    }
    else if (dist & GGX) {
        float tanThetaSq = alpha * alpha * xi.x / (1.0f - xi.x);
        cosTheta = 1.0f / native_sqrt(1.0f + tanThetaSq);
    }

    float r = native_sqrt(fmax(1.0f - cosTheta * cosTheta, 0.0f));
    return (float3)(native_cos(phi) * r, native_sin(phi) * r, cosTheta);
}

#endif
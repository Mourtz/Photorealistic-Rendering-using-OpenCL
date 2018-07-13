#ifndef __QUAD__
#define __QUAD__

/* Quad intesection */
bool intersect_quad(const Mesh* plane, Ray* ray) {

	const float3 v0 = plane->joker.s012;
	const float3 v1 = plane->joker.s345;
	const float3 v2 = plane->joker.s678;
	const float3 v3 = plane->joker.s9ab;

	// diagonal edges
	const float3 edge0 = v0 - v2;
	const float3 edge1 = v1 - v3;
	
	float3 n = cross(edge1, edge0)*plane->joker.sC;
	float area = fast_length(n);
	n /= area;

	float2 invUvSq = 1.0f/(float2)(dot(edge0, edge0), dot(edge1, edge1));

	float nDotW = dot(n, ray->dir);
	if (nDotW < 1e-6f)
		return false;

	float3 base = -edge0*0.5f - edge1*0.5f;
	float t = dot(n, base - ray->origin)/nDotW;
    if (t < EPS || t > ray->t)
		return false;

    float3 q = ray->origin + t*ray->dir;
    float3 v = q - base;
    float l0 = dot(v, edge0)*invUvSq.x;
    float l1 = dot(v, edge1)*invUvSq.y;

	if (l0 < 0.0f || l0 > 1.0f || l1 < 0.0f || l1 > 1.0f)
        return false;

	ray->t = t;
	ray->pos = q;
	ray->normal = n;
	//ray->uv = (float2)(l0, l1);

	return true;
}

#endif
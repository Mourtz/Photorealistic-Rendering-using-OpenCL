#ifndef __QUAD__
#define __QUAD__

#define _base  plane->joker.s012
#define _edge0 plane->joker.s345
#define _edge1 plane->joker.s678
#define _normal plane->joker.s9ab
#define _area plane->joker.sC

/* Quad intesection */
bool intersect_quad(const Mesh* plane, Ray* ray) {
	float nDotW = dot(_normal, ray->dir);
	
	// parallel or backside
	if (nDotW < EPS5) return false;

	float3 anchor = _base - (_edge0 + _edge1) * 0.5f;

	float rt = dot(_normal, anchor - ray->origin) / nDotW;
	if (rt < EPS3 || rt > ray->t)
		return false;

	// ray-quad intersection point
	float3 q = ray->origin + rt * ray->dir;

	float3 v = q - anchor;
	float l0 = dot(v, _edge0) / dot(_edge0, _edge0);
	float l1 = dot(v, _edge1) / dot(_edge1, _edge1);

	if (l0 < 0.0f || l0 > 1.0f || l1 < 0.0f || l1 > 1.0f)
		return false;

	ray->backside = false;
	ray->normal = _normal;
	ray->pos = q;
	ray->t = rt;
	return true;
}

bool quad_sampleDirect(const Mesh* plane, const float3* p, LightSample* sample, RNG_SEED_PARAM) {
	if (dot(_normal, *p - _base) <= 0.0f)
		return false;

	float2 xi = next2D(RNG_SEED_VALUE);
	float3 q = _base + xi.x * _edge0 + xi.y * _edge1;
	sample->d = q - *p;
	float rSq = dot(sample->d, sample->d);
	sample->dist = native_sqrt(rSq);
	sample->d /= sample->dist;
	float cosTheta = -dot(_normal, sample->d);
	sample->pdf = rSq / (cosTheta * _area);

	return true;
}


#undef _base
#undef _edge0
#undef _edge1
#undef _normal
#undef _area

#endif
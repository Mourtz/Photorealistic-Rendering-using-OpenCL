#if defined(QUAD) && !defined(__QUAD__)
#define __QUAD__

#define _base  plane->joker->s012
#define _edge0 plane->joker->s345
#define _edge1 plane->joker->s678
#define _normal plane->joker->s9ab
#define _area plane->joker->sC

/* Quad intesection */
inline bool intersect_quad(const float16 val, Ray* ray) {
	const float3 base = val.s012;
	const float3 edge0 = val.s345;
	const float3 edge1 = val.s678;
	const float3 normal = val.s9ab;


	float nDotW = dot(normal, ray->dir);
	
	// parallel or backside
	if (nDotW < 1e-5) return false;

	float3 anchor = base - (edge0 + edge1) * 0.5f;

	float rt = dot(normal, anchor - ray->origin) / nDotW;
	if (rt <= EPS || rt >= ray->t)
		return false;

	// ray-quad intersection point
	float3 q = ray->origin + rt * ray->dir;

	float3 v = q - anchor;
	float l0 = dot(v, edge0) / dot(edge0, edge0);
	float l1 = dot(v, edge1) / dot(edge1, edge1);

	if (l0 < 0.0f || l0 > 1.0f || l1 < 0.0f || l1 > 1.0f)
		return false;

	ray->backside = false;
	ray->normal = normal;
	ray->pos = q;
	ray->t = rt;
	// UV coordinates and tangent for texture mapping
	ray->uv = (float2)(l0, l1);
	ray->tangent = normalize(edge0);
	return true;
}

bool quad_sampleDirect(
	const float3 base,
	const float3 edge0,
	const float3 edge1,
	const float3 normal,
	const float area,
	const float3* p,
	LightSample* sample,
	RNG_SEED_PARAM
) {
	if (dot(normal, *p - base) <= 0.0f)
		return false;

	float2 xi = next2D(RNG_SEED_VALUE);
	float3 q = base + xi.x * edge0 + xi.y * edge1;
	sample->d = q - *p;
	float rSq = dot(sample->d, sample->d);
	sample->dist = sqrt(rSq);
	sample->d /= sample->dist;
	float cosTheta = -dot(normal, sample->d);
	sample->pdf = rSq / (cosTheta * area);

	return true;
}


float quad_directPdf(
	const float3 base,
	const float3 normal,
	const float area,
	const float3* dir,
	const float3* p
) {
	float cosTheta = fabs(dot(normal, *dir));
	float t = dot(normal, base - *p) / dot(normal, *dir);

	return t * t / (cosTheta * area);
}


#undef _base
#undef _edge0
#undef _edge1
#undef _normal
#undef _area

#endif
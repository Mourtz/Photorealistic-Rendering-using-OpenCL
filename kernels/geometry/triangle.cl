#ifndef __TRIANGLE__
#define __TRIANGLE__

/* Triangle intersection */
float3 flatTriAndRayIntersect(
	const float3 a, const float3 b, const float3 c,
	const Ray* ray, float* t, const float tNear
) {
	const float f = fmax(0.0f, tNear - 0.001f);
	const float3 closeOrigin = fma(ray->dir, f, ray->origin);
	const float3 edge1 = b - a;
	const float3 edge2 = c - a;
	const float3 tVec = closeOrigin - a;
	const float3 pVec = cross(ray->dir, edge2);
	const float3 qVec = cross(tVec, edge1);
	const float invDet = native_recip(dot(edge1, pVec));

	*t = dot(edge2, qVec) * invDet;

	if (*t >= ray->t || *t < EPS) {
		*t = INF;
		return (float3)(0.0f);
	}

	const float u = dot(tVec, pVec) * invDet;
	const float v = dot(ray->dir, qVec) * invDet;

	if (u + v > 1.0f || fmin(u, v) < 0.0f) {
		*t = INF;
		return (float3)(0.0f);
	}

	*t += f;

	return fast_normalize(cross(edge1, edge2));
}

float3 checkFaceIntersection(
	const Scene* scene, const Ray* ray, const int fIndex, float* t,
	const float tNear, const float tFar
) {
	const uint4 fv = scene->facesV[fIndex];
	const float3 a = scene->vertices[fv.x].xyz;
	const float3 b = scene->vertices[fv.y].xyz;
	const float3 c = scene->vertices[fv.z].xyz;

	return flatTriAndRayIntersect(a, b, c, ray, t, tNear);
}

#endif

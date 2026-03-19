#ifndef __TRIANGLE__
#define __TRIANGLE__

bool intersectTriangle(
	const Scene* scene, Ray* ray, const uint fIndex
) {
	const uint fv = scene->indices[fIndex]*3;
	const float3 p0 = scene->vertices[fv+0].xyz;
	const float3 p1 = scene->vertices[fv+1].xyz;
	const float3 p2 = scene->vertices[fv+2].xyz;

	const float3 e1 = p1 - p0;
	const float3 e2 = p2 - p0;
	
	const float3 h = cross(ray->dir, e2);
	float a = dot(e1, h);
	
	if (a > -EPS && a < EPS) {
		return false;
	}
	
	const float f = native_recip(a);
	
	const float3 s = ray->origin - p0;
	float u = f * dot(s, h);
	
	if (u < 0.0f || u > 1.0f) {
		return false;
	}
	
	const float3 q = cross(s, e1);
	float v = f * dot(ray->dir, q);
	
	if (v < 0.0f || u + v > 1.0f) {
		return false;
	}
	
	const float t = f * dot(e2, q);
	
	if (t > EPS && t < ray->t) {
		ray->t = t;
#if 1  /* smooth shading */
		const float3 n0 = scene->normals[fv+0].xyz;
		const float3 n1 = scene->normals[fv+1].xyz;
		const float3 n2 = scene->normals[fv+2].xyz;

		float w = 1.0f - u - v;
		ray->normal = w * n0 + u * n1 + v * n2;
#else
		ray->normal = e1; /* fallback to edge normal */
#endif
		return true;
	}

	return false;
}

#endif

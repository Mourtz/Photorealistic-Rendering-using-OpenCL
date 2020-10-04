#ifndef __TRIANGLE__
#define __TRIANGLE__

bool intersectTriangle(
	const Scene* scene, Ray* ray, const uint fIndex
) {
	const uint fv = scene->indices[fIndex]*3;
	const float3 p0 = scene->vertices[fv+0].xyz;
	const float3 p1 = scene->vertices[fv+1].xyz;
	const float3 p2 = scene->vertices[fv+2].xyz;

	const float3 e1 = p0 - p1;
	const float3 e2 = p2 - p0;

#if 0
	const float3 n0 = scene->normals[fv+0].xyz;
	const float3 n1 = scene->normals[fv+1].xyz;
	const float3 n2 = scene->normals[fv+2].xyz;
	const float3 n = (n0 + n1 + n2)/3.0f;
#else
	const float3 n = cross(e1, e2);
#endif

	float3 c = p0 - ray->origin;
	float3 r = cross(ray->dir, c);
	float inv_det = native_recip(dot(n, ray->dir));

	float u = dot(r, e2) * inv_det;
	float v = dot(r, e1) * inv_det;
	float w = 1.0f - u - v;

	if(u >= 0 && v >= 0 && w >= 0){
		float t = dot(n, c) * inv_det;
		if(t > EPS && t < ray->t){
			ray->t = t;
			ray->normal = n;
			return true;
		}
	}

	return false;
}

#endif

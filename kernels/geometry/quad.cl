#ifndef __QUAD__
#define __QUAD__

/* Quad intesection */
bool intersect_quad(const Mesh* plane, Ray* ray) {

	const float3 v0 = plane->joker.s012;
	const float3 v1 = plane->joker.s345;
	const float3 v2 = plane->joker.s678;
	const float3 v3 = plane->joker.s9ab;

	float3 v = v2 - v0;
	float3 u = v1 - v0;
	const float3 n = fast_normalize(cross(v, u)) * plane->joker.sC;

	float3 w0 = ray->origin - v0;
	float a = -dot(n, w0);
	float b = dot(n, ray->dir);
	
	// parallel or backside
	if (b < 0.0001f) return false;

	// get intersect point of ray with quad plane
	const float rt = a / b;
	if (rt < EPS || rt >= ray->t)
		return false;

	const float3 x = ray->origin + rt * ray->dir; // intersect point of ray and plane

	// is x inside first Triangle?
	float uu = dot(u, u);
	float uv = dot(u, v);
	float vv = dot(v, v);
	float3 w = x - v0;
	float wu = dot(w, u);
	float wv = dot(w, v);
	float D = 1.0f / (uv * uv - uu * vv);

	// get and test parametric coords
	float s = (uv * wv - vv * wu) * D;
	if (s >= 0.0f && s <= 1.0f)
	{
		float t = (uv * wu - uu * wv) * D;
		if (t >= 0.0f && (s + t) <= 1.0f)
		{
			ray->backside = false;
			ray->normal = -n;
			ray->pos = x;
			ray->t = rt;
			return true;
		}
	}

	// is x inside second Triangle?
	u = v3 - v0;
	uu = dot(u, u);
	uv = dot(u, v);
	wu = dot(w, u);
	D = 1.0f / (uv * uv - uu * vv);

	// get and test parametric coords
	s = (uv * wv - vv * wu) * D;
	if (s >= 0.0f && s <= 1.0f)
	{
		float t = (uv * wu - uu * wv) * D;
		if (t >= 0.0f && (s + t) <= 1.0f)
		{
			ray->backside = false;
			ray->normal = -n;
			ray->pos = x;
			ray->t = rt;
			return true;
		}
	}

	return false;
}

#endif
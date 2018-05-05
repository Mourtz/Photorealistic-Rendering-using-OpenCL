#ifndef __BOX__
#define __BOX__

/* box intesection */
bool intersect_box(__constant Mesh* box, Ray* ray) {
	const float3 invDir = native_recip(ray->dir);

	const float3 tmin = (box->pos + box->joker.s012 - ray->origin) * invDir;
	const float3 tmax = (box->pos - box->joker.s012 - ray->origin) * invDir;

	const float3 real_min = fmin(tmin, tmax);
	const float3 real_max = fmax(tmin, tmax);

	const float minmax = fmin(fmin(real_max.x, real_max.y), real_max.z);
	const float maxmin = fmax(fmax(real_min.x, real_min.y), real_min.z);

	if (minmax <= maxmin)
		return false;

	if (maxmin > 0.0f) // outside the box
	{
		if(maxmin < ray->t){ 
			ray->normal = -sign(ray->dir) * step(real_min.yzx, real_min) * step(real_min.zxy, real_min);
			ray->t = maxmin;
			ray->backside = false;
			return true;
		}
	}
	else if (minmax > 0.0f) // inside the box
	{
		if (minmax < ray->t) {
			ray->normal = -sign(ray->dir) * step(real_max, real_max.yzx) * step(real_max, real_max.zxy);
			ray->t = minmax;
			ray->backside = true;
			return true;
		}
	}

	return false;
}

#endif
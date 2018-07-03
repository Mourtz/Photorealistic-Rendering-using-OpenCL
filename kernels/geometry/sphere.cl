#ifndef __SPHERE__
#define __SPHERE__

/* sphere intesection */
bool intersect_sphere(Ray* ray, const Mesh* sphere) {

#if 1 // faster by 2ms! :P
	float3 p = ray->origin - sphere->pos;
	float B = dot(p, ray->dir);
    float C = dot(p, p) - sphere->joker.x * sphere->joker.x ;
    float detSq = B*B - C;
	if (detSq >= 0.0f) {
		float det = native_sqrt(detSq);
		float t = -B - det;
		if (t < ray->t && t > EPS) {
			ray->t = t;
			//ray->backside = false;
			return true;
		}
		t = -B + det;
		if (t < ray->t && t > EPS) {
			ray->t = t;
			//ray->backside = true;
			return true;
		}
    }

#else
	float3 rayToCenter = sphere->pos - ray->origin;
	float b = dot(rayToCenter, ray->dir);
	float det = b * b - dot(rayToCenter, rayToCenter) + sphere->joker.x * sphere->joker.x;

	if (det < 0.0f) return false;
	det = native_sqrt(det);

	*dist = b - det;
	if (*dist > EPS && *dist <= ray->t) return true;
	*dist = b + det;
	if (*dist > EPS && *dist <= ray->t) return true;
#endif

	return false;
}

float sphere_area(const Mesh* sphere){
	return FOUR_PI * sphere->joker.x * sphere->joker.x;
}

#endif
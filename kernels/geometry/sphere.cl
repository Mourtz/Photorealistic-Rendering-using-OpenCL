#ifndef __SPHERE__
#define __SPHERE__

/* sphere intesection */
bool intersect_sphere(const Ray* ray, float* dist, __constant Mesh* sphere) {

	float3 rayToCenter = sphere->pos - ray->origin;
	float b = dot(rayToCenter, ray->dir);
	float det = b * b - dot(rayToCenter, rayToCenter) + sphere->joker.x * sphere->joker.x;

	if (det < 0.0f) return false;
	det = sqrt(det);

	*dist = b - det;
	if (*dist > EPS && *dist <= ray->t) return true;
	*dist = b + det;
	if (*dist > EPS && *dist <= ray->t) return true;

	return false;
}

float sphere_area(__constant Mesh* sphere){
	return FOUR_PI * sphere->joker.x * sphere->joker.x;
}

#endif
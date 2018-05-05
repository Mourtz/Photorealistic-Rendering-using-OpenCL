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

bool sphere_sampleDirect(float3 p, LightSample* l_sample, const Mesh* sphere, uint* seed0, uint* seed1){
	float3 L = sphere->pos - p;
	float d = length(L);
	float C = d * d - sphere->joker.x * sphere->joker.x;
	if (C <= 0.0f)
		return false;
	
	L = normalize(L);
	float cosTheta = sqrt(C) / d;
	l_sample->d = uniformSphericalCap((float2)(get_random(seed0, seed1), get_random(seed0, seed1)), cosTheta);

	float B = d * l_sample->d.z;
	float det = sqrt(fmax(B*B - C, 0.0f));
	l_sample->dist = B - det;

	float3 u, v;
	calc_binormals(l_sample->d, &u, &v);
	l_sample->d =
		u * l_sample->d.x,
		v * l_sample->d.y,
		l_sample->d * l_sample->d.z;

	l_sample->pdf = INV_TWO_PI / (1.0f - cosTheta);

	return true;
}

float sphere_area(__constant Mesh* sphere){
	return FOUR_PI * sphere->joker.x * sphere->joker.x;
}

#endif
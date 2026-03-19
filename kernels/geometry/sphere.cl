#if defined(SPHERE) && !defined(__SPHERE__)
#define __SPHERE__

/* sphere intesection */
inline bool intersect_sphere(Ray* ray, const float3 sphere_pos, const float sphere_radius) {

#if 1 // faster by 2ms! :P
	float3 p = ray->origin - sphere_pos;
	float B = dot(p, ray->dir);
    float C = dot(p, p) - sphere_radius * sphere_radius;
    float detSq = B*B - C;
	if (detSq >= 0.0f) {
		float det = sqrt(detSq);
		float t = -B - det;
		if (t < ray->t && t > EPS) {
			ray->t = t;
			return true;
		}
		t = -B + det;
		if (t < ray->t && t > EPS) {
			ray->t = t;
			return true;
		}
    }

#else
	float3 rayToCenter = *sphere->pos - ray->origin;
	float b = dot(rayToCenter, ray->dir);
	float discriminant = b * b - dot(rayToCenter, rayToCenter) + sphere->value[0] * sphere->value[0];

	if (discriminant < 0.0f) return false;
	discriminant = sqrt(discriminant);

	float t1 = b - discriminant;
	if (t1 > EPS && t1 < ray->t) {
		ray->t = t1;
		return true;
	}
	float t2 = b + discriminant;
	if (t2 > EPS && t2 < ray->t) {
		ray->t = t2;
		return true;
	}
#endif

	return false;
}

inline float sphere_solidAngle(const Mesh* sphere, const float3* p) {
	float3 L = *sphere->pos - *p;
	float d = fast_length(L);
	float cosTheta = sqrt(fmax(d * d - sphere->value[0] * sphere->value[0], 0.0f)) / d;

	return TWO_PI * (1.0f - cosTheta);
}

inline float sphere_approximateRadiance(const Mesh* sphere, const float3* p){
	return sphere_solidAngle(sphere, p) * fmax3(sphere->mat->color);
}

inline float sphere_area(const Mesh* sphere){
	return FOUR_PI * sphere->value[0] * sphere->value[0];
}

inline float sphere_directPdf(const float3 sphere_pos, const float sphere_radius, const float3* p) {
	float dist = length(sphere_pos - *p);
	float cosTheta = sqrt(fmax(dist * dist - sphere_radius * sphere_radius, 0.0f)) / dist;
	return uniformSphericalCapPdf(cosTheta);
}

bool sphere_sampleDirect(const float3 sphere_pos, const float sphere_radius, const float3* p, LightSample* sample, RNG_SEED_PARAM) {
	float3 L = sphere_pos - *p;
	float d = length(L);
	float C = d * d - sphere_radius * sphere_radius;

	if (C <= 0.0f)
		return false;

	L = normalize(L);
	float cosTheta = sqrt(C) / d;

	sample->d = uniformSphericalCap(next2D(RNG_SEED_VALUE), cosTheta);

	float B = d * sample->d.z;
	float det = sqrt(fmax(B * B - C, 0.0f));
	sample->dist = B - det;

	TangentFrame frame = createTangentFrame(&L);
	sample->d = toGlobal(&frame, cosTheta);
	sample->pdf = uniformSphericalCapPdf(cosTheta);

	return true;
}

#endif
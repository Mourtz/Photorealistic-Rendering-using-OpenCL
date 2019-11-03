#if defined(SPHERE) && !defined(__SPHERE__)
#define __SPHERE__

/* sphere intesection */
bool intersect_sphere(Ray* ray, const Mesh* sphere) {

#if 1 // faster by 2ms! :P
	float3 p = ray->origin - sphere->pos;
	float B = dot(p, ray->dir);
    float C = dot(p, p) - sphere->radius * sphere->radius ;
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
	float3 rayToCenter = sphere->pos - ray->origin;
	float b = dot(rayToCenter, ray->dir);
	float det = b * b - dot(rayToCenter, rayToCenter) + sphere->radius * sphere->radius;

	if (det < 0.0f) return false;
	det = sqrt(det);

	*dist = b - det;
	if (*dist > EPS && *dist < ray->t) return true;
	*dist = b + det;
	if (*dist > EPS && *dist < ray->t) return true;
#endif

	return false;
}

float sphere_solidAngle(const Mesh* sphere, const float3* p) {
	float3 L = sphere->pos - *p;
	float d = fast_length(L);
	float cosTheta = sqrt(fmax(d * d - sphere->radius * sphere->radius, 0.0f)) / d;

	return TWO_PI * (1.0f - cosTheta);
}

float sphere_approximateRadiance(const Mesh* sphere, const float3* p){
	return sphere_solidAngle(sphere, p) * fmax3(sphere->mat.color);
}

float sphere_area(const Mesh* sphere){
	return FOUR_PI * sphere->radius * sphere->radius;
}

float sphere_directPdf(const Mesh* sphere, const float3* p) {
	float dist = length(sphere->pos - *p);
	float cosTheta = sqrt(fmax(dist * dist - sphere->radius * sphere->radius, 0.0f)) / dist;
	return uniformSphericalCapPdf(cosTheta);
}

bool sphere_sampleDirect(const Mesh* sphere, const float3* p, LightSample* sample, RNG_SEED_PARAM) {
	float3 L = sphere->pos - *p;
	float d = length(L);
	float C = d * d - sphere->radius * sphere->radius;

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
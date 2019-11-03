#ifndef __T_BASE__
#define __T_BASE__

__constant bool enableLightSampling = true;
__constant bool enableVolumeLightSampling = true;
__constant bool lowOrderScattering = true;

#define CONSISTENCY_CHECKS 0
#define PICK_RANDOM_LIGHT 0

SurfaceScatterEvent makeLocalScatterEvent(Ray* ray, const Scene* scene) {
	TangentFrame frame = createTangentFrame(&ray->normal);
	return (SurfaceScatterEvent){ toLocal(&frame, -ray->dir) , (float3)(0.0), (float3)(1.0), 1.0, NullLobe, NullLobe, frame };
}

SurfaceScatterEvent makeForwardEvent(const SurfaceScatterEvent* event){
	SurfaceScatterEvent copy = *event;
	copy.wo = -copy.wi;
	copy.requestedLobe = ForwardLobe;
	return copy;
}

inline float powerHeuristic(float pdf0, float pdf1){
	return (pdf0 * pdf0) / (pdf0 * pdf0 + pdf1 * pdf1);
}

/*--------------------------- LIGHT ---------------------------*/

#ifdef LIGHT

float3 bsdfSample(
	SurfaceScatterEvent* event,
	Ray* ray,
	const Medium* medium,
	const Scene* scene,
	RNG_SEED_PARAM,
	const Material* mat,
	bool* terminate
) {
	if (!BSDF2(event, ray, scene, mat, RNG_SEED_VALUE, false)) {
		*terminate = true;
		return (float3)(0.0f);
	}

	float3 wo = toGlobal(&event->frame, event->wo);

#if CONSISTENCY_CHECKS
	bool geometricBackside = (dot(wo, ray->normal) < 0.0f);
	bool shadingBackside = (event->wo.z < 0.0f) ^ ray->backside;

	if (geometricBackside == shadingBackside)
#endif
	{
		ray->origin = ray->pos;
		ray->dir = wo;

		int mesh_id;
		if (intersect_scene(ray, &mesh_id, scene)) {
			const Mesh light = scene->meshes[mesh_id];

			if (light.mat.t & LIGHT) {
				//*terminate = true;
				float3 contribution = light.mat.color * event->weight *
					powerHeuristic(event->pdf, directPdf(&light, &ray->dir, &ray->pos));

#ifdef GLOBAL_MEDIUM
				if (medium != NULL)
					contribution *= exp(-medium->sigmaT * ray->t);
#endif

				return contribution;
			}
		}
	}

	return (float3)(0.0f);
}

float3 lightSample(
	SurfaceScatterEvent* event,
	const Ray* ray,
	const Medium* medium,
	const Scene* scene,
	RNG_SEED_PARAM,
	const Material* mat
) {

#if PICK_RANDOM_LIGHT
	// pick a random light source
	const Mesh light = scene->meshes[LIGHT_INDICES[(int)(next1D(RNG_SEED_VALUE) * (float)(LIGHT_COUNT + 1))]];
#else
	const Mesh light = scene->meshes[LIGHT_INDICES[0]];
#endif

	LightSample rec;

	if (!sampleDirect(&light, &ray->pos, &rec, RNG_SEED_VALUE))
		return (float3)(0.0f);

	event->wo = toLocal(&event->frame, rec.d);

#if CONSISTENCY_CHECKS
	bool geometricBackside = (dot(rec.d, ray->normal) < 0.0f);
	bool shadingBackside = (event->wo.z < 0.0f) ^ ray->backside;

	if (geometricBackside == shadingBackside)
#endif
	{
		float3 fr = BSDF_eval2(event, mat, false);

		if (dot(fr, fr) == 0.0)
			return (float3)(0.0f);

		Ray shadowRay;
		shadowRay.origin = ray->pos;
		shadowRay.dir = rec.d;
		shadowRay.t = rec.dist;

		if (shadow(&shadowRay, scene)) {
			float3 contribution = light.mat.color * fr;

#ifdef GLOBAL_MEDIUM
			if (medium != NULL)
				contribution *= exp(-medium->sigmaT * shadowRay.t);
#endif

			contribution *= powerHeuristic(rec.pdf, BSDF_pdf(event, mat));
			return contribution/rec.pdf;
		}
	}


	return (float3)(0.0f);
}

#endif

bool handleSurface(
	SurfaceScatterEvent* event,
	Ray* ray,
	const Medium* medium,
	const Scene* scene,
	RNG_SEED_PARAM,
	Material* mat,
	__global RLH* rlh,
	float3* emmision
) {
	bool terminate = false;

#if 0	// Dispersion Test
#if defined(DIEL) && defined(ROUGH_DIEL)
	if (mat->t & (DIEL | ROUGH_DIEL))
#elif defined(DIEL)
	if (mat->t & DIEL)
#elif defined(ROUGH_DIEL)
	if (mat->t & ROUGH_DIEL)
#else
	if (false)
#endif
	{
		return false;
		float _min = fmin3(mat->eta_t);
		float _max = fmax3(mat->eta_t);
		mat->eta_t.x = dot(rlh->mask, mat->eta_t) / dot(rlh->mask, 1.0f);
	}
#endif // End of Dispersion Test

#ifdef LIGHT
	if (enableLightSampling && mat->lobes & ~(SpecularLobe|ForwardLobe)) {
		*emmision += (bsdfSample(event, ray, medium, scene, RNG_SEED_VALUE, mat, &terminate)+
			lightSample(event, ray, medium, scene, RNG_SEED_VALUE, mat)) * rlh->mask;
	}
	else
#endif
	{
		if (!BSDF2(event, ray, scene, mat, RNG_SEED_VALUE, false)) {
			return true;
		}

		ray->origin = ray->pos;
		ray->dir = toGlobal(&event->frame, event->wo);
	}

	rlh->bounce.wasSpecular = event->sampledLobe & SpecularLobe;

	rlh->mask *= event->weight;
	rlh->bounce.diff += (event->sampledLobe & (DiffuseReflectionLobe| GlossyReflectionLobe)) != 0;
	rlh->bounce.spec += (event->sampledLobe & SpecularReflectionLobe) != 0;
	rlh->bounce.trans += (event->sampledLobe & TransmissiveLobe) != 0;

	return terminate;
}

float3 volumeLightSample(
	MediumSample* mediumSample,
	const Medium* medium,
	const Ray* ray,
	const Scene* scene,
	RNG_SEED_PARAM,
	const Material* mat
){
#if PICK_RANDOM_LIGHT
	// pick a random light source
	const Mesh light = scene->meshes[LIGHT_INDICES[(int)(next1D(RNG_SEED_VALUE) * (float)(LIGHT_COUNT + 1))]];
#else
	const Mesh light = scene->meshes[LIGHT_INDICES[0]];
#endif

	LightSample rec;

	if(!sampleDirect(&light, &ray->pos, &rec, RNG_SEED_VALUE))
		return (float3)(0.0f);

	float3 f = phase_eval(ray->dir, rec.d);
	if (dot(f, f) == 0.0f)
		return (float3)(0.0f);

	Ray sRay;
	sRay.origin = mediumSample->p;
	sRay.dir = rec.d;
	sRay.t = rec.dist;

	if (shadow(&sRay, scene)) {
		float3 contribution = exp(-medium->sigmaT * sRay.t) * light.mat.color * f *
			powerHeuristic(rec.pdf, phase_pdf(ray->dir, rec.d));
		return contribution / rec.pdf;
	}

	return (float3)(0.0f);
}

float3 volumePhaseSample(
	MediumSample* mediumSample,
	PhaseSample* phaseSample,
	const Medium* medium,
	const Ray* ray,
	const Scene* scene,
	RNG_SEED_PARAM,
	const Material* mat
){
	if (!phase_sample(ray->dir, phaseSample, RNG_SEED_VALUE)) {
		return (float3)(0.0f);
	}

	Ray sRay;
	sRay.origin = mediumSample->p;
	sRay.dir = phaseSample->w;

	int mesh_id;
	if (intersect_scene(&sRay, &mesh_id, scene)) {
		const Mesh light = scene->meshes[mesh_id];

		if (light.mat.t & LIGHT) {
			return exp(-medium->sigmaT * sRay.t) * light.mat.color * phaseSample->weight *
				powerHeuristic(phaseSample->pdf, directPdf(&light, &sRay.dir, &mediumSample->p));
		}
	}

	return (float3)(0.0f);
}

#endif

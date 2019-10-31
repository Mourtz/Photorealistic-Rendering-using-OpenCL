#ifndef __T_BASE__
#define __T_BASE__

__constant bool enableVolumeLightSampling = false;
__constant bool lowOrderScattering = false;
#define CONSISTENCY_CHECKS 0

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

/*--------------------------- LIGHT ---------------------------*/

#ifdef LIGHT

inline float powerHeuristic(float pdf0, float pdf1)
{
	return (pdf0 * pdf0) / (pdf0 * pdf0 + pdf1 * pdf1);
}

float3 bsdfSample(
	SurfaceScatterEvent* event,
	Ray* ray,
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

				float dPdf = -1e3;
#ifdef __SPHERE__
				if (light.t & SPHERE)
#else
				if (false)
#endif
				{
					dPdf = sphere_directPdf(&light, &ray->pos);
				}
#ifdef __QUAD__
				else if (light.t & QUAD) {
					dPdf = quad_directPdf(ray, &light, &ray->pos);
				}
#endif

				return light.mat.color * event->weight * powerHeuristic(event->pdf, dPdf);
			}
		}
	}

	return (float3)(0.0f);
}

float3 lightSample(
	SurfaceScatterEvent* event,
	const Ray* ray,
	const Scene* scene,
	RNG_SEED_PARAM,
	const Material* mat
) {

#if 0
	const Mesh light = scene->meshes[LIGHT_INDICES[0]];
#else
	// pick a random light source
	const Mesh light = scene->meshes[LIGHT_INDICES[(int)(next1D(RNG_SEED_VALUE) * (float)(LIGHT_COUNT+1))]];
#endif

	LightSample rec;

#ifdef __SPHERE__
	if (light.t & SPHERE)
#else
	if (false)
#endif
	{
		if (!sphere_sampleDirect(&light, &ray->pos, &rec, RNG_SEED_VALUE))
			return (float3)(0.0f);
	}
#ifdef __QUAD__
	else if (light.t & QUAD) {
		if (!quad_sampleDirect(&light, &ray->pos, &rec, RNG_SEED_VALUE))
			return (float3)(0.0f);
	}
#endif

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
			float3 contribution = light.mat.color * fr / rec.pdf;
			contribution *= powerHeuristic(rec.pdf, BSDF_pdf(event, mat));
			return contribution;
		}
	}


	return (float3)(0.0f);
}

#endif

bool handleSurface(
	SurfaceScatterEvent* event,
	Ray* ray,
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
	if (mat->lobes & ~(SpecularLobe|ForwardLobe)) {
		*emmision += (bsdfSample(event, ray, scene, RNG_SEED_VALUE, mat, &terminate)+
			lightSample(event, ray, scene, RNG_SEED_VALUE, mat)) * rlh->mask;
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

#endif

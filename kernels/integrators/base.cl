#ifndef __T_BASE__
#define __T_BASE__

SurfaceScatterEvent makeLocalScatterEvent(Ray* ray, const Scene* scene) {
	TangentFrame frame = createTangentFrame(&ray->normal);
	return (SurfaceScatterEvent){ toLocal(&frame, -ray->dir) , (float3)(0.0), (float3)(1.0), 1.0, frame };
}

/*--------------------------- LIGHT ---------------------------*/

#ifdef LIGHT

inline float powerHeuristic(float pdf0, float pdf1)
{
	return (pdf0 * pdf0) / (pdf0 * pdf0 + pdf1 * pdf1);
}

float3 bsdfSample(
	SurfaceScatterEvent* event,
	const Ray* ray,
	const Scene* scene,
	RNG_SEED_PARAM,
	const Material* mat
) {
	if (mat->t & DIFF) {
		LambertBSDF(ray, event, mat, RNG_SEED_VALUE);
	}
	
	float3 wo = toGlobal(&event->frame, event->wo);

	Ray shadowRay;
	shadowRay.origin = ray->origin;
	shadowRay.dir = wo;

#if 1
	bool geometricBackside = (dot(wo, ray->normal) < 0.0f);
	bool shadingBackside = (event->wo.z < 0.0f) ^ ray->backside;

	if (geometricBackside == shadingBackside)
#endif
	{
		int mesh_id;

		if (intersect_scene(&shadowRay, &mesh_id, scene)) {
			if (!shadowRay.backside) {
				const Mesh mesh = scene->meshes[mesh_id];
				const Material mat = mesh.mat;

				if (mat.t & LIGHT) {
					float3 contribution = mat.color * event->weight;
					contribution *= powerHeuristic(event->pdf, sphere_directPdf(&mesh, &ray->origin));
					return contribution;
				}
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
	const Mesh light = scene->meshes[LIGHT_INDICES[0]];

	// pick a random light source
	//const Mesh light = scene->meshes[LIGHT_INDICES[(int)(next1D(RNG_SEED_VALUE) * (float)(LIGHT_COUNT+1))]];

	LightSample rec;

#ifdef __SPHERE__
	if (light.t & SPHERE) {
		if (!sphere_sampleDirect(&light, &ray->origin, &rec, RNG_SEED_VALUE))
			return (float3)(0.0f);
	}
#endif

	Ray shadowRay;
	shadowRay.origin = ray->origin;
	shadowRay.dir = rec.d;
	shadowRay.t = rec.dist;

	event->wo = toLocal(&event->frame, rec.d);

#if 1
	bool geometricBackside = (dot(rec.d, ray->normal) < 0.0f);
	bool shadingBackside = (event->wo.z < 0.0f) ^ ray->backside;

	if (geometricBackside == shadingBackside)
#endif
	{
		if (mat->t & DIFF) {
			float3 fr = LambertBSDF_eval(event, mat);

			if (dot(fr, fr) == 0.0)
				return (float3)(0.0f);

			if (shadow(&shadowRay, scene)) {
				float3 contribution = (light.mat.color * fr) / rec.pdf;
				contribution *= powerHeuristic(rec.pdf, LambertBSDF_pdf(event));
				return contribution;
			}

		}
	}


	return (float3)(0.0f);
}

#endif

#endif

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
	const int c_mesh_id
) {
	float3 Lo = (float3)(0.0f);

	const Mesh c_mesh = scene->meshes[c_mesh_id];
	if (c_mesh.mat.t & DIFF) {
		LambertBSDF(ray, event, &c_mesh.mat, RNG_SEED_VALUE);
	}
	
	float3 wo = toGlobal(&event->frame, event->wo);

	float dotNWo = dot(wo, ray->normal);
	if (dotNWo > 0.0f) {
		Ray shadowRay;
		shadowRay.origin = ray->origin;
		shadowRay.dir = wo;


		int mesh_id;

		if (intersect_scene(&shadowRay, &mesh_id, scene)) {
			const Mesh mesh = scene->meshes[mesh_id];
			const Material mat = mesh.mat;

			if (mat.t & LIGHT) {
				float cosAtLight = dot(shadowRay.normal, -wo);

				if (cosAtLight > 0.0) {
					float3 contribution = mat.color * event->weight;
#if 1

					//float lightPdfW = sphericalLightSamplingPdf( x, wi );//pLight->pdfIlluminate(x, wo, distanceToLight, cosAtLight) * lightPickPdf;

					contribution *= powerHeuristic(event->pdf, sphere_directPdf(&mesh, &ray->origin));
#endif

					Lo += contribution;
				}
			}
		}
	}

	return Lo;
}

float3 lightSample(
	SurfaceScatterEvent* event,
	const Ray* ray,
	const Scene* scene,
	RNG_SEED_PARAM,
	const int c_mesh_id

) {
	float3 Lo = (float3)(0.0f);	//outgoing radiance

	const Mesh c_mesh = scene->meshes[c_mesh_id];
	const Mesh light = scene->meshes[LIGHT_INDICES[0]];

	// pick a random light source
	//const Mesh light = scene->meshes[LIGHT_INDICES[(int)(next1D(RNG_SEED_VALUE) * (float)(LIGHT_COUNT+1))]];

	LightSample rec;

#ifdef __SPHERE__
	if (light.t & SPHERE) {
		if (!sphere_sampleDirect(&light, &ray->origin, &rec, RNG_SEED_VALUE))
			return Lo;
	}
#endif

	event->wo = toLocal(&event->frame, rec.d);

	//bool geometricBackside = (dot(rec.d, ray->normal) < 0.0f);
	//bool shadingBackside = (event->wo.z < 0.0f) ^ ray->backside;

	float dotNWo = dot(rec.d, ray->normal);

	if (dotNWo > 0.0f) {
		if (c_mesh.mat.t & DIFF) {
			float3 fr = LambertBSDF_eval(event, &c_mesh.mat);

			if (dot(fr, fr) == 0.0)
				return Lo;

			Ray shadowRay;
			shadowRay.origin = ray->origin;
			shadowRay.dir = rec.d;
			shadowRay.t = rec.dist;

			if (shadow(&shadowRay, scene)) {
				float3 contribution = (light.mat.color * fr) / rec.pdf;

#if 1
				contribution *= powerHeuristic(rec.pdf, LambertBSDF_pdf(event));
#endif

				Lo += contribution;
			}
			
		}
	}

	return Lo;
}

#endif

#endif

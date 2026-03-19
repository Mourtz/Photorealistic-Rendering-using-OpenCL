#ifndef __T_BASE__
#define __T_BASE__

#define CONSISTENCY_CHECKS 0
#define PICK_RANDOM_LIGHT 1

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
	float denominator = (pdf0 * pdf0) + (pdf1 * pdf1);
	return (pdf0 * pdf0) / max(denominator, 1e-6f);
}

/*--------------------------- LIGHT ---------------------------*/

#ifdef LIGHT

float selectLight_WRS(
	const Scene* scene,
	uint params,
	uint* out_light_id,
	RNG_SEED_PARAM
) {
#if PICK_RANDOM_LIGHT
	if (RP_RIS(params)) {
		uint   selected_id     = LIGHT_INDICES[0];
		float  selected_target = 1e-10f;
		float  w_sum           = 0.0f;
		int    m_count         = RP_RIS_M(params);

		for (int m = 0; m < m_count; m++) {
			uint idx      = min((uint)(next1D(RNG_SEED_VALUE) * (float)LIGHT_COUNT), (uint)(LIGHT_COUNT - 1));
			uint light_id = LIGHT_INDICES[idx];

			// Target function: luminance of emission (proposal is uniform = 1/LIGHT_COUNT)
			float3 em  = scene->mesh_mats[light_id].color;
			float tgt  = 0.2126f * em.x + 0.7152f * em.y + 0.0722f * em.z;
			float w    = tgt * (float)LIGHT_COUNT; // w_i = tgt / (1/LIGHT_COUNT)

			w_sum += w;
			// WRS accept with prob w/w_sum (reservoir update)
			if (next1D(RNG_SEED_VALUE) * w_sum < w) {
				selected_id     = light_id;
				selected_target = max(tgt, 1e-10f);
			}
		}

		*out_light_id = selected_id;
		// W_RIS = sum(w_i) / (M * f(selected))
		// When all targets equal: W_RIS = LIGHT_COUNT (matches uniform case)
		return w_sum / ((float)m_count * selected_target);
	} else {
		uint idx      = min((uint)(next1D(RNG_SEED_VALUE) * (float)LIGHT_COUNT), (uint)(LIGHT_COUNT - 1));
		*out_light_id = LIGHT_INDICES[idx];
		return (float)LIGHT_COUNT; // = 1 / INV_LIGHT_COUNT
	}
#else
	*out_light_id = LIGHT_INDICES[0];
	return 1.0f;
#endif
}

float3 bsdfSample(
	SurfaceScatterEvent* event,
	Ray* ray,
	const Medium* medium,
	const Scene* scene,
	uint params,
	RNG_SEED_PARAM,
	const Material* mat,
	bool* terminate,
	__read_only image2d_t env_map,
	const EnvMapIS* envIS
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
			if (mesh_id < 0)
				return (float3)(0.0f);
			const Material lightMat = scene->mesh_mats[mesh_id];

			if (lightMat.t & LIGHT) {
				float neePdf = directPdfScene(scene, (uint)mesh_id, &ray->dir, &ray->pos) * INV_LIGHT_COUNT;
				float3 contribution = lightMat.color * event->weight;
				if (RP_MIS(params))
					contribution *= powerHeuristic(event->pdf, neePdf);

#ifdef GLOBAL_MEDIUM
				if (medium != NULL)
					contribution *= native_exp(-medium->sigmaT * ray->t);
#endif

				return contribution;
			}
		} else {
			if (RP_ENVMAP_IS(params) && envIS->width > 1) {
				float3 Le = read_imagef(env_map, samplerA, envMapEquirect(wo)).xyz;
				float envPdf = envMapPdf(wo, envIS);
				float3 contribution = Le * event->weight;
				if (RP_MIS(params) && envPdf > 0.0f)
					contribution *= powerHeuristic(event->pdf, envPdf);
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
	uint params,
	RNG_SEED_PARAM,
	const Material* mat
) {
	uint light_id;
	float W_ris = selectLight_WRS(scene, params, &light_id, RNG_SEED_VALUE);
	const Material lightMat = scene->mesh_mats[light_id];

	LightSample rec;
	if (!sampleDirectScene(scene, light_id, &ray->pos, &rec, RNG_SEED_VALUE))
		return (float3)(0.0f);

	// combinedPdf = rec.pdf * (1/W_ris) = rec.pdf / W_ris
	// contribution = lightColor * fr * mis_w / combinedPdf
	//              = lightColor * fr * mis_w * W_ris / rec.pdf
	float combinedPdf = rec.pdf / W_ris;

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
			float3 contribution = lightMat.color * fr;

#ifdef GLOBAL_MEDIUM
			if (medium != NULL)
				contribution *= native_exp(-medium->sigmaT * shadowRay.t);
#endif

			if (RP_MIS(params))
				contribution *= powerHeuristic(combinedPdf, BSDF_pdf(event, mat));

			return contribution / combinedPdf;
		}
	}

	return (float3)(0.0f);
}

// Direct env-map lighting (NEE for the sky).
// Samples a direction from the importance-sampling CDF, tests visibility,
// and returns the weighted contribution (caller multiplies by rlh->mask).
float3 envLightSample(
	SurfaceScatterEvent* event,
	const Ray* ray,
	const Medium* medium,
	const Scene* scene,
	__read_only image2d_t env_map,
	const EnvMapIS* envIS,
	uint params,
	RNG_SEED_PARAM,
	const Material* mat
) {
	if (!RP_ENVMAP_IS(params) || envIS->width <= 1)
		return (float3)(0.0f);

	float envPdf;
	float3 dir = envMapSample(
		(float2)(next1D(RNG_SEED_VALUE), next1D(RNG_SEED_VALUE)),
		envIS, &envPdf);

	if (envPdf <= 0.0f)
		return (float3)(0.0f);

	event->wo = toLocal(&event->frame, dir);

#if CONSISTENCY_CHECKS
	bool geometricBackside = (dot(dir, ray->normal) < 0.0f);
	bool shadingBackside   = (event->wo.z < 0.0f) ^ ray->backside;
	if (geometricBackside != shadingBackside)
		return (float3)(0.0f);
#endif

	float3 fr = BSDF_eval2(event, mat, false);
	if (dot(fr, fr) == 0.0f)
		return (float3)(0.0f);

	Ray shadowRay;
	shadowRay.origin = ray->pos;
	shadowRay.dir    = dir;
	shadowRay.t      = 1e30f;

	if (shadow(&shadowRay, scene)) {
		float3 Le = read_imagef(env_map, samplerA, envMapEquirect(dir)).xyz;
		float3 contribution = Le * fr / envPdf;

		if (RP_MIS(params))
			contribution *= powerHeuristic(envPdf, BSDF_pdf(event, mat));

		return contribution;
	}

	return (float3)(0.0f);
}

float3 volumeLightSample(
	MediumSample* mediumSample,
	const Medium* medium,
	const Ray* ray,
	const Scene* scene,
	uint params,
	RNG_SEED_PARAM,
	const Material* mat
){
	uint light_id;
	float W_ris = selectLight_WRS(scene, params, &light_id, RNG_SEED_VALUE);
	const Material lightMat = scene->mesh_mats[light_id];

	LightSample rec;
	if(!sampleDirectScene(scene, light_id, &ray->pos, &rec, RNG_SEED_VALUE))
		return (float3)(0.0f);

	float combinedPdf = rec.pdf / W_ris;

	float3 f = phase_eval(ray->dir, rec.d);
	if (dot(f, f) == 0.0f)
		return (float3)(0.0f);

	Ray sRay;
	sRay.origin = mediumSample->p;
	sRay.dir = rec.d;
	sRay.t = rec.dist;

	if (shadow(&sRay, scene)) {
		float3 contribution = native_exp(-medium->sigmaT * sRay.t) * lightMat.color * f;
		if (RP_MIS(params))
			contribution *= powerHeuristic(combinedPdf, phase_pdf(ray->dir, rec.d));
		return contribution / combinedPdf;
	}

	return (float3)(0.0f);
}

float3 volumePhaseSample(
	MediumSample* mediumSample,
	PhaseSample* phaseSample,
	const Medium* medium,
	const Ray* ray,
	const Scene* scene,
	uint params,
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
		if (mesh_id < 0)
			return (float3)(0.0f);

		const Material lightMat = scene->mesh_mats[mesh_id];

		if (lightMat.t & LIGHT) {
			float3 contribution = native_exp(-medium->sigmaT * sRay.t) * lightMat.color * phaseSample->weight;
			if (RP_MIS(params))
				contribution *= powerHeuristic(phaseSample->pdf, directPdfScene(scene, (uint)mesh_id, &sRay.dir, &mediumSample->p));
			return contribution;
		}
	}

	return (float3)(0.0f);
}

#endif  /* LIGHT */

bool handleSurface(
	SurfaceScatterEvent* event,
	Ray* ray,
	const Medium* medium,
	const Scene* scene,
	uint params,
	RNG_SEED_PARAM,
	Material* mat,
	RLH* rlh,
	float3* emmision,
	__read_only image2d_t env_map,
	const EnvMapIS* envIS
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
	if (RP_NEE(params) && mat->lobes & ~(SpecularLobe|ForwardLobe)) {
		float3 bsdf_c  = bsdfSample(event, ray, medium, scene, params, RNG_SEED_VALUE, mat, &terminate, env_map, envIS);
		float  bsdf_pdf = event->pdf;
		float3 light_c = lightSample(event, ray, medium, scene, params, RNG_SEED_VALUE, mat);
		float3 env_c   = envLightSample(event, ray, medium, scene, env_map, envIS, params, RNG_SEED_VALUE, mat);
		*emmision += (bsdf_c + light_c + env_c) * rlh->mask;
		rlh->last_bsdf_pdf = bsdf_pdf;
	}
	else
#endif
	{
		if (!BSDF2(event, ray, scene, mat, RNG_SEED_VALUE, false)) {
			return true;
		}

		rlh->last_bsdf_pdf = event->pdf;
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

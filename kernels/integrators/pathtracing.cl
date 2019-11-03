#ifndef __INTEGRATOR__
#define __INTEGRATOR__

float4 radiance(
	const Scene* scene,
	__read_only image2d_t env_map,
	Ray* ray,
	__global RLH* rlh,
	RNG_SEED_PARAM
){
#ifdef GLOBAL_MEDIUM
	const Medium _medium = (Medium){
		(float3)(GLOBAL_FOG_DENSITY),
		(float3)(GLOBAL_FOG_SIGMA_A),
		(float3)(GLOBAL_FOG_SIGMA_S),
		(float3)(GLOBAL_FOG_SIGMA_T),
		GLOBAL_FOG_ABS_ONLY
	};
	const Medium* medium = &_medium;
#else
	const Medium* medium = NULL;
#endif

	float alpha = 1.0f;
	float3 emission = (float3)(0.0f);
#define acc (float4)(emission, alpha)

	int mesh_id;
	bool didHit = intersect_scene(ray, &mesh_id, scene);

	const Mesh mesh = scene->meshes[mesh_id];
	Material mat = (mesh_id + 1) ? mesh.mat : *scene->mat;

/*------------------- GLOBAL MEDIUM -------------------*/
#ifdef GLOBAL_MEDIUM
	MediumSample mediumSample;
	mediumSample.continuedWeight = rlh->mask;

	HomogeneousMedium_sampleDistance(&mediumSample, medium, ray, RNG_SEED_VALUE);

	rlh->mask *= mediumSample.weight;
	
	// scatter
	if (!mediumSample.exited && rlh->bounce.scatters < MAX_SCATTERING_EVENTS){
		++rlh->bounce.scatters;
		
		PhaseSample phaseSample;

		rlh->bounce.wasSpecular = !(enableVolumeLightSampling && (lowOrderScattering || rlh->bounce.scatters > 1));

		if (!rlh->bounce.wasSpecular) {
			emission += (
				volumeLightSample(&mediumSample, medium, ray, scene, RNG_SEED_VALUE, &mat) +
				volumePhaseSample(&mediumSample, &phaseSample, medium, ray, scene, RNG_SEED_VALUE, &mat)
			) * rlh->mask;
		}

		ray->origin = mediumSample.p;
		ray->dir = phaseSample.w;

		rlh->mask *= phaseSample.weight;
	} else 
#endif
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	{
		if (!didHit) {
			rlh->reset = true;

#ifdef ALPHA_TESTING
			return (float4)(0.0f);
#else
			return (float4)(rlh->mask * read_imagef(env_map, samplerA, envMapEquirect(ray->dir)).xyz, 1.0f);
#endif
		}

#ifdef LIGHT
		if (mat.t & LIGHT) {
			if (!enableLightSampling || rlh->bounce.wasSpecular)
				emission += mat.emission * rlh->mask;

			rlh->reset = true;
			return acc;
		}
#endif

		SurfaceScatterEvent surfaceEvent = makeLocalScatterEvent(ray, scene);

		if (handleSurface(&surfaceEvent, ray, medium, scene, RNG_SEED_VALUE, &mat, rlh, &emission)) {
			rlh->reset = true;
			return acc;
		}

		rlh->bounce.scatters = 0;
		++rlh->bounce.total;
	}

	//russian roulette
	const float roulettePdf = fmax3(rlh->mask);
	if (rlh->bounce.total > 2 && roulettePdf < 0.1f) {
		if (next1D(RNG_SEED_VALUE) < roulettePdf){
			rlh->mask /= roulettePdf;
		} else {
			rlh->reset = true;
			return acc;
		}
	}

	/* terminate if necessary */
	if (rlh->bounce.total >= MAX_BOUNCES ||
		rlh->bounce.diff >= MAX_DIFF_BOUNCES ||
		rlh->bounce.spec >= MAX_SPEC_BOUNCES ||
		rlh->bounce.trans >= MAX_TRANS_BOUNCES
	) {
		rlh->reset = true;
	}

	return acc;

#undef acc
}

#endif

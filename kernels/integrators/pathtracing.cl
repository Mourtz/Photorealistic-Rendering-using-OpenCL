#ifndef __INTEGRATOR__
#define __INTEGRATOR__

float4 radiance(
	const Scene* scene,
	__read_only image2d_t env_map,
	Ray* ray,
	__global RLH* rlh,
	RNG_SEED_PARAM
){
	++rlh->bounce.total;

	SurfaceScatterEvent surfaceEvent;

	float alpha = 1.0f;
	float3 emission = (float3)(0.0f);
#define acc (float4)(emission, alpha)

	int mesh_id;
	if (!intersect_scene(ray, &mesh_id, scene)) {
		rlh->bounce.total = 0;

		#ifdef ALPHA_TESTING
			return (float4)(0.0f);
		#else
			return (float4)(rlh->mask * read_imagef(env_map, samplerA, envMapEquirect(ray->dir)).xyz, 1.0f);
		#endif
	}
	//rlh->mesh_id = mesh_id;

	const Mesh mesh = scene->meshes[mesh_id];
	Material mat = (mesh_id + 1) ? mesh.mat : *scene->mat;

/*------------------- GLOBAL MEDIUM -------------------*/
#ifdef GLOBAL_MEDIUM
	Medium medium;
	medium.density = GLOBAL_FOG_DENSITY;
	medium.sigmaA = GLOBAL_FOG_SIGMA_A;
	medium.sigmaS = GLOBAL_FOG_SIGMA_S;
	medium.sigmaT = GLOBAL_FOG_SIGMA_T;
	medium.absorptionOnly = GLOBAL_FOG_ABS_ONLY;

	MediumSample mediumSample;
	mediumSample.continuedWeight = rlh->mask;
	sampleDistance(ray, &mediumSample, &medium, RNG_SEED_VALUE);
	rlh->mask *= mediumSample.weight;
	
	if (++rlh->bounce.scatters < 1024 && !mediumSample.exited){
		//rlh->bounce.wasSpecular = !(enableVolumeLightSampling && (lowOrderScattering /*|| rlh->media.scatters > 1*/));
		rlh->bounce.wasSpecular = !(enableVolumeLightSampling && (lowOrderScattering || rlh->bounce.scatters > 1));

		emission += (
			volumeLightSample(&mediumSample, &medium, ray, scene, RNG_SEED_VALUE, &mat) +
			volumePhaseSample(&mediumSample, &medium, ray, scene, RNG_SEED_VALUE, &mat)
		) * rlh->mask;

		PhaseSample phaseSample;
		hg_sample(ray->dir, &phaseSample, RNG_SEED_VALUE);
		
		ray->origin = mediumSample.p;
		ray->dir = phaseSample.w;

		rlh->mask *= phaseSample.weight;
	} else 
#endif
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	{

#ifdef LIGHT
		if (mat.t & LIGHT) {
			if (rlh->bounce.wasSpecular)
				emission += mat.emission * rlh->mask;

			rlh->bounce.total = 0;
			return acc;
		}
#endif

		surfaceEvent = makeLocalScatterEvent(ray, scene);

		if (handleSurface(&surfaceEvent, ray, scene, RNG_SEED_VALUE, &mat, rlh, &emission)) {
			rlh->bounce.total = 0;
			return acc;
		}
	}

	//russian roulette
	const float roulettePdf = fmax3(rlh->mask);
	if (rlh->bounce.total > 3 && roulettePdf < 0.1f) {
		if (next1D(RNG_SEED_VALUE) < roulettePdf){
			rlh->mask /= roulettePdf;
		} else {
			rlh->bounce.total = 0;
			return acc;
		}
	}

	/* terminate if necessary */
	if (rlh->bounce.total >= MAX_BOUNCES ||
		rlh->bounce.diff >= MAX_DIFF_BOUNCES ||
		rlh->bounce.spec >= MAX_SPEC_BOUNCES ||
		rlh->bounce.trans >= MAX_TRANS_BOUNCES
	) {
		rlh->bounce.total = 0;
	}

	return acc;

#undef acc
}

#endif

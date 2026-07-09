#ifndef __INTEGRATOR__
#define __INTEGRATOR__

float4 radiance(
	const Scene* scene,
	__read_only image2d_t env_map,
	const EnvMapIS* envIS,
	__read_only image2d_array_t mat_textures,
	Ray* ray,
	RLH* rlh,
	const __constant RenderParams* params,
	RNG_SEED_PARAM
) {
	const uint rp = *params;

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

	int mesh_id;
	bool didHit = intersect_scene(ray, &mesh_id, scene);

	const Mesh mesh = sceneGetMesh(scene, mesh_id);

	Material mat = (mesh_id + 1) ? loadMaterial(scene, mesh_id) : loadMaterial(scene, scene->mesh_count[7]);

#ifdef GLOBAL_MEDIUM
	MediumSample mediumSample;
	mediumSample.continuedWeight = rlh->mask;

	HomogeneousMedium_sampleDistance(&mediumSample, medium, ray, RNG_SEED_VALUE);

	rlh->mask *= mediumSample.weight;

	// scatter
	if (!mediumSample.exited && rlh->bounce.scatters < MAX_SCATTERING_EVENTS){
		++rlh->bounce.scatters;

		PhaseSample phaseSample;

		rlh->bounce.wasSpecular = !(RP_NEE(rp) && (lowOrderScattering || rlh->bounce.scatters > 1));

		if (!rlh->bounce.wasSpecular) {
#ifdef LIGHT
			emission += (
				volumeLightSample(&mediumSample, medium, ray, scene, rp, RNG_SEED_VALUE, &mat) +
				volumePhaseSample(&mediumSample, &phaseSample, medium, ray, scene, rp, RNG_SEED_VALUE, &mat)
			) * rlh->mask;
#endif
		}

		ray->origin = mediumSample.p;
		ray->dir = phaseSample.w;

		rlh->mask *= phaseSample.weight;
	} else
#endif

	if (!didHit) {
		rlh->reset = true;
#ifdef ALPHA_TESTING
		return (float4)(0.0f);
#else
		{
			float3 Le = read_imagef(env_map, samplerA, envMapEquirect(ray->dir)).xyz;
			float3 contrib = rlh->mask * Le;
			// MIS: weight the env-map contribution against the last BSDF sample
			if (RP_ENVMAP_IS(rp) && RP_MIS(rp) && !rlh->bounce.wasSpecular && envIS->width > 1) {
				float envPdf = envMapPdf(ray->dir, envIS);
				if (envPdf > 0.0f)
					contrib *= powerHeuristic(rlh->last_bsdf_pdf, envPdf);
			}
			return (float4)(emission + contrib, 1.0f);
		}
#endif
	}

	{
		const int2 texCoord = (int2)(
			(int)(ray->uv.x * (float)MAT_TEX_SIZE) & (MAT_TEX_SIZE - 1),
			(int)(ray->uv.y * (float)MAT_TEX_SIZE) & (MAT_TEX_SIZE - 1)
		);
		if (mat.normalMapIdx >= 0) {
			float4 ts = read_imagef(mat_textures, (int4)(texCoord.x, texCoord.y, mat.normalMapIdx, 0));
			float3 n_ts = normalize(ts.xyz * 2.0f - 1.0f);
			float3 N = ray->normal;
			float3 T = ray->tangent;
			T = normalize(T - dot(T, N) * N); // re-orthogonalise
			float3 B = cross(N, T);
			ray->normal = normalize(n_ts.x * T + n_ts.y * B + n_ts.z * N);
		}
		if (mat.roughnessMapIdx >= 0) {
			float4 rs = read_imagef(mat_textures, (int4)(texCoord.x, texCoord.y, mat.roughnessMapIdx, 0));
			mat.roughness = rs.x;
		}
	}

#ifdef LIGHT
	if (mat.t & LIGHT) {
		if (!RP_NEE(rp) || rlh->bounce.wasSpecular)
			emission += mat.emission * rlh->mask;
		rlh->reset = true;
		return (float4)(emission, alpha);
	}
#endif

	SurfaceScatterEvent surfaceEvent = makeLocalScatterEvent(ray, scene);

	if (handleSurface(&surfaceEvent, ray, medium, scene, rp, RNG_SEED_VALUE, &mat, rlh, &emission, env_map, envIS)) {
		rlh->reset = true;
		return (float4)(emission, alpha);
	}

	rlh->bounce.scatters = 0;
	++rlh->bounce.total;

	if (rlh->bounce.total >= 3) {
		const float roulettePdf = fmin(fmax3(rlh->mask), 1.0f);
		if (next1D(RNG_SEED_VALUE) >= roulettePdf) {
			rlh->reset = true;
			return (float4)(emission, alpha);
		}
		rlh->mask /= roulettePdf;
	}

	if (rlh->bounce.total >= MAX_BOUNCES ||
		rlh->bounce.diff >= MAX_DIFF_BOUNCES ||
		rlh->bounce.spec >= MAX_SPEC_BOUNCES ||
		rlh->bounce.trans >= MAX_TRANS_BOUNCES
	) {
		rlh->reset = true;
	}

	return (float4)(emission, alpha);
}

#endif

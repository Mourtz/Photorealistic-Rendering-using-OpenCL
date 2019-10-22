#ifndef __INTEGRATOR__
#define __INTEGRATOR__

__constant bool enableLightSampling			= true;
__constant bool enableVolumeLightSampling 	= false;
__constant bool lowOrderScattering 			= false;



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
	float3 emmision = (float3)(0.0f);
#define acc (float4)(emmision, alpha)

	// if ray is not in a meadium
	if(!rlh->media.in){
		int mesh_id;
		// intersection check
		if (!intersect_scene(ray, &mesh_id, scene)) {
			rlh->bounce.total = 0;

			#ifdef ALPHA_TESTING
				return (float4)(0.0f);
			#else
				return (float4)(rlh->mask * read_imagef(env_map, samplerA, envMapEquirect(ray->dir)).xyz, 1.0f);
			#endif
		}
		rlh->mesh_id = mesh_id;
	}

/*------------------- GLOBAL MEDIUM -------------------*/
#ifdef GLOBAL_MEDIUM
	const float gm_hg_g = 0.5f;

	// global medium
	// const Medium g_medium = {
		// (float3)(GLOBAL_FOG_DENSITY),
		// (float3)(GLOBAL_FOG_SIGMA_A),
		// (float3)(GLOBAL_FOG_SIGMA_S),
		// (float3)(GLOBAL_FOG_SIGMA_T),
		// GLOBAL_FOG_ABS_ONLY
	// };

	Medium g_medium;
	g_medium.density = GLOBAL_FOG_DENSITY;
	g_medium.sigmaA = GLOBAL_FOG_SIGMA_A;
	g_medium.sigmaS = GLOBAL_FOG_SIGMA_S;
	g_medium.sigmaT = GLOBAL_FOG_SIGMA_T;
	g_medium.absorptionOnly = GLOBAL_FOG_ABS_ONLY;

	MediumSample gm_sample;
	sampleDistance(ray, &gm_sample, &g_medium, RNG_SEED_VALUE);
	rlh->mask *= gm_sample.weight;
	
	if (++rlh->media.scatters < 1024 && !gm_sample.exited){
		ray->origin = gm_sample.p;

		rlh->bounce.isSpecular = !(enableVolumeLightSampling && (lowOrderScattering || rlh->media.scatters > 1));

#if 0
		/* Henyey-Greenstein phase function */
		PhaseSample p_sample;
		hg_sample(ray->dir, gm_hg_g, &p_sample, RNG_SEED_VALUE);
		ray->dir = p_sample.w;
#else 
		ray->dir = uniformSphere((float2)(next1D(RNG_SEED_VALUE), next1D(RNG_SEED_VALUE)));
#endif
		// @ToDo clear this thing out, fix the light sampling code!!!!!!!
		ray->normal = ray->dir;
	} else 
#endif
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	{
		const Mesh mesh = scene->meshes[rlh->mesh_id];
		const Material mat = (rlh->mesh_id + 1) ? mesh.mat : *scene->mat;

		surfaceEvent = makeLocalScatterEvent(ray, scene);

#if 1
#ifdef LIGHT
		if (enableLightSampling) {
			ray->origin = ray->pos + ray->normal * EPS;

			float3 dLight = lightSample(&surfaceEvent, ray, scene, RNG_SEED_VALUE, rlh->mesh_id);
			//dLight += bsdfSample(&surfaceEvent, ray, scene, RNG_SEED_VALUE, rlh->mesh_id);

			// emmision += dLight * rlh->mask * hg_eval(ray->dir, fast_normalize(vwi), gm_hg_g) * exp(-(fast_length(vwi)+gm_sample.t)*g_medium.sigmaT);
			emmision += dLight * rlh->mask;
		}
#endif
#endif

#if 1
#ifdef LIGHT
		if (mat.t & LIGHT /*&& rlh->bounce.isSpecular*/) {
			if (!enableLightSampling || rlh->bounce.isSpecular)
				emmision += rlh->mask * mat.color;

			rlh->bounce.total = 0;
			return acc;
		}
#endif
#endif

		/*-------------------- DIFFUSE --------------------*/
#ifdef DIFF
		if (mat.t & DIFF) 
#else
		if (false) 
#endif
		{
			LambertBSDF(ray, &surfaceEvent, &mat, RNG_SEED_VALUE);
			rlh->mask *= surfaceEvent.weight;

			ray->origin = ray->pos + ray->normal * EPS;
			ray->dir = toGlobal(&surfaceEvent.frame, surfaceEvent.wo);


			++rlh->bounce.diff;
			rlh->bounce.isSpecular = false;
		}
		/*-------------------- CONDUCTOR --------------------*/
#ifdef COND
		else if (mat.t & COND)
		{
			if (!Conductor(ray, &surfaceEvent, &mat, RNG_SEED_VALUE)){
				rlh->bounce.total = 0;
				return acc;
			}

			rlh->mask *= surfaceEvent.weight;

			++rlh->bounce.spec;
			rlh->bounce.isSpecular = true;
		}
#endif
		/*-------------------- ROUGH CONDUCTOR (GGX|BECKMANN|PHONG) --------------------*/
#ifdef ROUGH_COND
		else if (mat.t & ROUGH_COND)
		{
			if (!RoughConductor(GGX, ray, &surfaceEvent, &mat, RNG_SEED_VALUE)){
				rlh->bounce.total = 0;
				return acc;
			}

			rlh->mask *= surfaceEvent.weight;

			++rlh->bounce.spec;
			rlh->bounce.isSpecular = true;
		}
#endif
		/*-------------------- DIELECTRIC --------------------*/
#ifdef DIEL
		else if (mat.t & DIEL) 
		{
			if (!DielectricBSDF(ray, &surfaceEvent, &mat, RNG_SEED_VALUE)){
				rlh->bounce.total = 0;
				return acc;
			}

			rlh->mask *= surfaceEvent.weight;

			++rlh->bounce.spec;
			rlh->bounce.isSpecular = true;
		}
#endif
		/*---------------- ROUGH DIELECTRIC (GGX|BECKMANN|PHONG) ----------------*/
#ifdef ROUGH_DIEL
		else if (mat.t & ROUGH_DIEL) 
		{
			if (!RoughDielectricBSDF(BECKMANN, ray, &surfaceEvent, &mat, RNG_SEED_VALUE)){
				rlh->bounce.total = 0;
				return acc;
			}

			rlh->mask *= surfaceEvent.weight;

			++rlh->bounce.spec;
			rlh->bounce.isSpecular = true;
		}
#endif
		/*-------------------- COAT --------------------*/
#ifdef COAT
		else if (mat.t & COAT)
		{
			/* reflect */
			if (next1D(RNG_SEED_VALUE) < schlick(ray->dir, ray->normal, 1.0f, 1.4f)) {
				ray->origin = ray->pos + ray->normal * EPS;
				ray->dir = fast_normalize(reflect(ray->dir, ray->normal));

				++rlh->bounce.spec;
				rlh->bounce.isSpecular = true;
			}
			/* diffuse */
			else {
				LambertBSDF(ray, &surfaceEvent, &mat, RNG_SEED_VALUE);

				rlh->mask *= surfaceEvent.weight;

				++rlh->bounce.diff;
				rlh->bounce.isSpecular = false;
			}
		}
#endif
	}

	/* terminate if necessary */
	if (rlh->bounce.total >= MAX_BOUNCES ||
		rlh->bounce.diff >= MAX_DIFF_BOUNCES || 
		rlh->bounce.spec >= MAX_SPEC_BOUNCES ||
		rlh->bounce.trans >= MAX_TRANS_BOUNCES
	) { 
		rlh->bounce.total = 0;
		return acc;
	}

	//russian roulette
	const float roulettePdf = fmax3(rlh->mask);
	if (roulettePdf < 0.1f) {
		if (next1D(RNG_SEED_VALUE) < roulettePdf){
			rlh->mask /= roulettePdf;
		} else {
			rlh->media.in = rlh->bounce.total = 0;
		}
	}

	return acc;

#undef acc
}

#endif

#ifndef __INTEGRATOR__
#define __INTEGRATOR__

__constant bool enableVolumeLightSampling 	= true;
__constant bool lowOrderScattering 			= false;

/*--------------------------- LIGHT ---------------------------*/

#ifdef LIGHT

float3 calcDirectLight(
	const Ray* ray,
	const Scene* scene,
	const uint* light_index,
	float3* wi,
	uint* seed0, uint* seed1,
	const int c_mesh_id

){ 
	const Mesh light = scene->meshes[*light_index];
	const Mesh c_mesh = scene->meshes[c_mesh_id];

	Ray shadowRay;
	shadowRay.origin = ray->origin;

	const float2 xi = (float2)(get_random(seed0, seed1), get_random(seed0, seed1));

#ifdef __SPHERE__
	if (light.t & SPHERE) {
		
		const float3 randPointOnLight = light.pos + uniformSphere(xi) * light.joker.x;

		*wi = randPointOnLight - shadowRay.origin;
		float d2 = dot(*wi, *wi);
		float len = native_sqrt(d2);
		shadowRay.dir = native_divide(*wi, len);

		if (ray->backside) {
			float thickness;
			if (get_dist(&thickness, &shadowRay, &c_mesh, scene, c_mesh_id == -1))
				shadowRay.origin += (thickness + EPS) * shadowRay.dir;
		}

		shadowRay.t = len;
		if (shadow(&shadowRay, scene)) {
			float r2 = light.joker.x * light.joker.x;

			float cos_a_max = native_sqrt(1.0f - clamp(r2 / d2, 0.0f, 1.0f));
			float weight = 2.0f * (1.0f - cos_a_max);
			return light.mat.color * weight;
		}
	}
#endif

#ifdef __QUAD__

#ifdef __SPHERE__
	else
#endif
	//------------------------------
	if (light.t & QUAD) {

		const float* verts = &light.joker;

		const float3 randPointOnLight = (float3)(
			mix(verts[0], verts[6], xi.x),
			verts[1],
			mix(verts[2], verts[5], xi.y)
		);

		*wi = randPointOnLight - shadowRay.origin;
		float d2 = dot(*wi, *wi);
		float len = native_sqrt(d2);
		shadowRay.dir = native_divide(*wi, len);

		if (ray->backside) {
			float thickness;
			if (get_dist(&thickness, &shadowRay, &c_mesh, scene, c_mesh_id == -1))
				shadowRay.origin += (thickness + EPS) * shadowRay.dir;
		}

		shadowRay.t = len;
		if (shadow(&shadowRay, scene)) {
			float r2 = fast_distance(light.joker.s012, light.joker.s345) * fast_distance(light.joker.s012, light.joker.s678);
			float weight = r2 / d2;
			return light.mat.color * clamp(weight, 0.0f, 1.0f) * 0.5f;
		}
	}
#endif

	return F3_ZERO;
}

#endif

float4 radiance(
	const Scene* scene,
	__read_only image2d_t env_map,
	Ray* ray,
	__global RLH* rlh,
	uint* seed0, uint* seed1
){
	++rlh->bounce.total;

	// if ray is not in a meadium
	if(!rlh->media.in){

		// intersection check
		if (!intersect_scene(ray, &rlh->mesh_id, scene)) {
			rlh->bounce.total = 0;

			#ifdef ALPHA_TESTING
				return (float4)(0.0f);
			#else
				return (float4)(rlh->mask * read_imagef(env_map, samplerA, envMapEquirect(ray->dir)).xyz, 1.0f);
			#endif
		}
	}
	
	float alpha = 1.0f;
	float3 emmision = (float3)(0.0f);
#define acc (float4)(emmision, alpha)

	float brdfPdf = 1.0f;

/*------------------- GLOBAL MEDIUM -------------------*/
#ifdef GLOBAL_MEDIUM
	const float gm_hg_g = 0.5f;

	// global medium
	Medium g_medium;
	g_medium.density = GLOBAL_FOG_DENSITY;
	g_medium.sigmaA = GLOBAL_FOG_SIGMA_A;
	g_medium.sigmaS = GLOBAL_FOG_SIGMA_S;
	g_medium.sigmaT = GLOBAL_FOG_SIGMA_T;
	g_medium.absorptionOnly = GLOBAL_FOG_ABS_ONLY;

	MediumSample gm_sample;
	sampleDistance(ray, &gm_sample, &g_medium, seed0, seed1);
	rlh->mask *= gm_sample.weight;
	
	if (!gm_sample.exited){
		ray->origin = gm_sample.p;

#ifdef LIGHT
		float3 vwi;
		for (uint i = 0; i < LIGHT_COUNT; ++i) {
			uint index = LIGHT_INDICES[i];

			if (fast_distance(ray->origin, scene->meshes[index].pos) >= INF) continue;

			float3 dLight = calcDirectLight(ray, scene, &index, &vwi, seed0, seed1, mesh_id);
			// @ToFix - im 100% sure this is wrong
			emmision += dLight * rlh->mask * hg_eval(ray->dir, fast_normalize(vwi), gm_hg_g) * exp(-(fast_length(vwi)+gm_sample.t)*g_medium.sigmaT);
		}
#endif

		/* Henyey-Greenstein phase function */
		PhaseSample p_sample;
		hg_sample(ray->dir, gm_hg_g, &p_sample, seed0, seed1);
		ray->dir = p_sample.w;
	} else 
#endif
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
	{
		const Mesh mesh = scene->meshes[rlh->mesh_id];
		const Material mat = (rlh->mesh_id + 1) ? mesh.mat : *scene->mat;

#ifdef LIGHT
		if (mat.t & LIGHT) {
			if (!rlh->bounce.isSpecular || rlh->bounce.total == 1)
				emmision += rlh->mask * mat.color;

			rlh->bounce.total = 0;
			return acc;
		}
#endif

		SurfaceScatterEvent surfaceEvent;

		/*-------------------- DIFFUSE --------------------*/
#ifdef DIFF
		if (mat.t & DIFF) 
#else
		if (false) 
#endif
		{
			LambertBSDF(ray, &surfaceEvent, &mat, seed0, seed1);
	
			rlh->mask *= surfaceEvent.weight;

			++rlh->bounce.diff;
			rlh->bounce.isSpecular = false;
		}
		/*-------------------- CONDUCTOR --------------------*/
#ifdef COND
		else if (mat.t & COND)
#else
		else if (false)
#endif
		{
			if (!Conductor(ray, &surfaceEvent, &mat, seed0, seed1)){
				rlh->bounce.total = 0;
				return acc;
			}

			rlh->mask *= surfaceEvent.weight;

			++rlh->bounce.spec;
			rlh->bounce.isSpecular = true;
		}
		/*-------------------- ROUGH CONDUCTOR (GGX|BECKMANN|PHONG) --------------------*/
#ifdef ROUGH_COND
		else if (mat.t & ROUGH_COND)
#else
		else if (false)
#endif
		{
			if (!RoughConductor(GGX, ray, &surfaceEvent, &mat, seed0, seed1)){
				rlh->bounce.total = 0;
				return acc;
			}

			rlh->mask *= surfaceEvent.weight;

			++rlh->bounce.spec;
			rlh->bounce.isSpecular = true;
		}

		/*-------------------- DIELECTRIC --------------------*/
#ifdef DIEL
		else if (mat.t & DIEL) 
#else
		else if (false) 
#endif
		
		{
			if (!DielectricBSDF(ray, &surfaceEvent, &mat, seed0, seed1)){
				rlh->bounce.total = 0;
				return acc;
			}

			rlh->mask *= surfaceEvent.weight;

			++rlh->bounce.spec;
			rlh->bounce.isSpecular = true;
		}
		/*---------------- ROUGH DIELECTRIC (GGX|BECKMANN|PHONG) ----------------*/
#ifdef ROUGH_DIEL
		else if (mat.t & ROUGH_DIEL) 
#else
		else if (false) 
#endif
		
		{
			if (!RoughDielectricBSDF(BECKMANN, ray, &surfaceEvent, &mat, seed0, seed1)){
				rlh->bounce.total = 0;
				return acc;
			}

			rlh->mask *= surfaceEvent.weight;

			++rlh->bounce.spec;
			rlh->bounce.isSpecular = true;
		}

		/*-------------------- COAT --------------------*/
#ifdef COAT
		else if (mat.t & COAT)
#else
		else if (false)
#endif
		{
			/* reflect */
			if (get_random(seed0, seed1) < schlick(ray->dir, ray->normal, 1.0f, 1.4f)) {
				ray->origin = ray->pos + ray->normal * EPS;
				ray->dir = fast_normalize(reflect(ray->dir, ray->normal));

				++rlh->bounce.spec;
				rlh->bounce.isSpecular = true;
			}
			/* diffuse */
			else {
				LambertBSDF(ray, &surfaceEvent, &mat, seed0, seed1);

				rlh->mask *= surfaceEvent.weight;

				++rlh->bounce.diff;
				rlh->bounce.isSpecular = false;
			}
		}
		/*-------------------- VOL --------------------*/
#ifdef VOL
		else if (mat.t & VOL) 
#else
		else if (false)
#endif
		{
			// get the ray inside the medium if its not already
			if (!ray->backside) {
				ray->origin = ray->pos - ray->normal * EPS;
				if (!get_dist(&ray->t, ray, &mesh, scene, rlh->mesh_id == -1)) {
					rlh->bounce.total = 0;
					return acc;	
				}
				ray->backside = true;
			}

			// max scattering events
			if(rlh->media.scatters++ < 1024){
				const float3 density = mat.color * 80.0f;
				const float sigmaA = 0.5f;
				const float sigmaS = 1.0f;
				const float sigmaT = sigmaA + sigmaS;

				// medium's properties
				const Medium medium = {
					density,
					sigmaA*density,
					sigmaS*density,
					sigmaT*density,
					(dot(sigmaS, 1.0f) == 0.0f)
				};

				MediumSample m_sample;
				sampleDistance(ray, &m_sample, &medium, seed0, seed1);

				rlh->mask *= m_sample.weight;

				if (m_sample.exited) {
					ray->origin = ray->origin + ray->dir * (ray->t + EPS);
					ray->backside = false;
				} else {
					float2 xi = (float2)(get_random(seed0, seed1), get_random(seed0, seed1));
					ray->origin = m_sample.p;
					#if 1
						ray->dir = uniformSphere(xi);
					#else
						hg_sample_fast(&ray->dir, 0.4f, &xi);
					#endif

					if (!get_dist(&ray->t, ray, &mesh, scene, rlh->mesh_id == -1)) {
						rlh->bounce.total = 0;
						return acc;
					}
				}
			} else {
				ray->origin = ray->origin + ray->dir * (ray->t + EPS);
				ray->backside = false;
			}
			ray->normal = ray->dir;
			rlh->media.in = ray->backside;

//@ToDo Volume Light Sampling needs work
#if 0
			rlh->bounce.isSpecular = ray->backside && !(enableVolumeLightSampling && (lowOrderScattering || rlh->media.scatters > 1));
#else
			rlh->bounce.isSpecular = ray->backside;
#endif
		}
		/*-------------------- TRANS --------------------
		else if (mat.t & TRANS) {

		}
		/*-------------------- SPECSUB --------------------*/
#ifdef SPECSUB
		else if (mat.t & SPECSUB)
#else
		else if (false)
#endif
		{
			if (get_random(seed0, seed1) < schlick(ray->dir, ray->normal, 1.0f, 1.3f)) {
				ray->origin = ray->pos + ray->normal * EPS;
				ray->dir = fast_normalize(reflect(ray->dir, ray->normal));

				++rlh->bounce.spec;
				rlh->bounce.isSpecular = true;
			}
			else {
				if (!ray->backside) {
					ray->origin = ray->pos - ray->normal * EPS;
					if (!get_dist(&ray->t, ray, &mesh, scene, rlh->mesh_id == -1)) return acc;
					ray->backside = true;
				}

				// max scattering events
				const int max_scatters = 1024;

				MediumSample m_sample;

				// medium's properties
				Medium medium;
				medium.density = mat.color * 40.0f;
				medium.sigmaA = 0.2f * medium.density;
				medium.sigmaS = 1.0f * medium.density;
				medium.sigmaT = (medium.sigmaA + medium.sigmaS);
				medium.absorptionOnly = (dot(medium.sigmaS,1.0f) == 0.0f);

				int scatters = 0;
				while (true) {
					sampleDistance(ray, &m_sample, &medium, seed0, seed1);

					rlh->mask *= m_sample.weight;

					if (m_sample.exited) {
						break;
					}

					ray->origin = m_sample.p;
#if 0
					hg_sample_fast(&ray->dir, 0.8f, seed0, seed1);
#else
					ray->dir = uniformSphere((float2)(get_random(seed0, seed1), get_random(seed0, seed1)));
#endif

					if (!get_dist(&ray->t, ray, &mesh, scene, rlh->mesh_id == -1)) return acc;

					//russian roulette
					float roulettePdf = fmax3(rlh->mask);
					if (roulettePdf < 0.1f) {
						if (get_random(seed0, seed1) < roulettePdf)
							rlh->mask = native_divide(rlh->mask, roulettePdf);
						else
							break;
					}

					if (++scatters > max_scatters) {
						break;
					}
				}

				ray->origin = ray->origin + ray->dir * (ray->t + EPS);
				ray->normal = ray->dir;
				ray->backside = rlh->bounce.isSpecular = false;
			}
		}

#ifdef LIGHT
		if (!rlh->bounce.isSpecular) {
			float3 wi;
			for (uint i = 0; i < LIGHT_COUNT; ++i) {
				uint index = LIGHT_INDICES[i];

				if (fast_distance(ray->origin, scene->meshes[index].pos) >= INF) continue;

				float3 dLight = calcDirectLight(ray, scene, &index, &wi, seed0, seed1, rlh->mesh_id);
				emmision += dLight * rlh->mask * fmax(0.01f, dot(fast_normalize(wi), ray->normal));
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
		if (get_random(seed0, seed1) < roulettePdf){
			rlh->mask /= roulettePdf;
		} else {
			rlh->media.in = rlh->bounce.total = 0;
		}
	}

	return acc;

#undef acc
}

#endif

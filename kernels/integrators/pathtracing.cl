#ifndef __INTEGRATOR__
#define __INTEGRATOR__

/*--------------------------- LIGHT ---------------------------*/

#ifdef HAS_LIGHTS

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
	__read_only image2d_t noise_tex,
	Ray* ray,
	uint* seed0, uint* seed1
){
	int mesh_id;

	if (!intersect_scene(ray, &mesh_id, scene)) {
#ifdef ALPHA_TESTING
		return (float4)(0.0f);
#else
		return (float4)(read_imagef(env_map, samplerA, envMapEquirect(ray->dir)).xyz, 1.0f);
#endif
	}

	uint DIFF_BOUNCES = 0, SPEC_BOUNCES = 0, TRANS_BOUNCES = 0, SCATTERING_EVENTS = 0, bounce = 0;

	float4 acc = (float4)(0.0f, 0.0f, 0.0f, 1.0f);
	float3 mask = (float3)(1.0f);
	float brdfPdf = 1.0f;

	SurfaceScatterEvent surfaceEvent;

	bool bounceIsSpecular = true;

#ifdef GLOBAL_MEDIUM
	const float gm_hg_g = 0.5f;

	MediumSample gm_sample;

	// global medium
	Medium g_medium;
	g_medium.density = GLOBAL_FOG_DENSITY;
	g_medium.sigmaA = GLOBAL_FOG_SIGMA_A;
	g_medium.sigmaS = GLOBAL_FOG_SIGMA_S;
	g_medium.sigmaT = GLOBAL_FOG_SIGMA_T;
	g_medium.absorptionOnly = GLOBAL_FOG_ABS_ONLY;
#endif

	do {

/*------------------- GLOBAL MEDIUM -------------------*/
#ifdef GLOBAL_MEDIUM
		sampleDistance(ray, &gm_sample, &g_medium, seed0, seed1);
		mask *= gm_sample.weight;
		const bool hitSurface = gm_sample.exited;
#endif

		/*------------------------------------------------------*/


#ifdef GLOBAL_MEDIUM
		if (hitSurface) 
#endif
		{
			const Mesh mesh = scene->meshes[mesh_id];
			const Material mat = (mesh_id + 1) ? mesh.mat : *scene->mat;

#ifdef HAS_LIGHTS
			if (mat.t & LIGHT) {
				if (!bounceIsSpecular)
					mask *= fmax(0.01f, dot(ray->dir, ray->normal));

				acc.xyz += mask * mat.color;
				break;
			}
#endif

			/*-------------------- DIFFUSE --------------------*/
#ifdef DIFF
			if (mat.t & DIFF) 
#else
			if (false) 
#endif
			{
				LambertBSDF(ray, &surfaceEvent, &mat, seed0, seed1);
		
				mask *= surfaceEvent.weight;

				++DIFF_BOUNCES;
				bounceIsSpecular = false;
			}
			/*-------------------- CONDUCTOR --------------------*/
#ifdef COND
			else if (mat.t & COND)
#else
			else if (false)
#endif
			{
				if (!Conductor(ray, &surfaceEvent, &mat, seed0, seed1))
					break;

				mask *= surfaceEvent.weight;

				++SPEC_BOUNCES;
				bounceIsSpecular = true;
			}
			/*-------------------- ROUGH CONDUCTOR (GGX|BECKMANN|PHONG) --------------------*/
#ifdef ROUGH_COND
			else if (mat.t & ROUGH_COND)
#else
			else if (false)
#endif
			{
				if (!RoughConductor(GGX, ray, &surfaceEvent, &mat, seed0, seed1))
					break;

				mask *= surfaceEvent.weight;

				++SPEC_BOUNCES;
				bounceIsSpecular = true;
			}

			/*-------------------- DIELECTRIC --------------------*/
#ifdef DIEL
			else if (mat.t & DIEL) 
#else
			else if (false) 
#endif
			
			{
				if (!DielectricBSDF(ray, &surfaceEvent, &mat, seed0, seed1))
					break;

				mask *= surfaceEvent.weight;

				//++SPEC_BOUNCES;
				bounceIsSpecular = true;
			}
			/*---------------- ROUGH DIELECTRIC (GGX|BECKMANN|PHONG) ----------------*/
#ifdef ROUGH_DIEL
			else if (mat.t & ROUGH_DIEL) 
#else
			else if (false) 
#endif
			
			{
				if (!RoughDielectricBSDF(BECKMANN, ray, &surfaceEvent, &mat, seed0, seed1))
					break;

				mask *= surfaceEvent.weight;

				//++SPEC_BOUNCES;
				bounceIsSpecular = true;
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

					++SPEC_BOUNCES;
					bounceIsSpecular = true;
				}
				/* diffuse */
				else {
					LambertBSDF(ray, &surfaceEvent, &mat, seed0, seed1);

					mask *= surfaceEvent.weight;

					++DIFF_BOUNCES;
					bounceIsSpecular = false;
				}
			}
			/*-------------------- VOL --------------------*/
#ifdef VOL
			else if (mat.t & VOL) 
#else
			else if (false)
#endif
			{
				if (!ray->backside) {
					ray->origin = ray->pos - ray->normal * EPS;
					if (!get_dist(&ray->t, ray, &mesh, scene, mesh_id == -1)) return acc;
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
				medium.absorptionOnly = (dot(medium.sigmaS, 1.0f) == 0.0f);

				int scatters = 0;
				while (true) {
					sampleDistance(ray, &m_sample, &medium, seed0, seed1);

					mask *= m_sample.weight;

					if (m_sample.exited) {
						break;
					}

					float2 xi = (float2)(get_random(seed0, seed1), get_random(seed0, seed1));
					ray->origin = m_sample.p;
					ray->dir = uniformSphere(xi);

					if (!get_dist(&ray->t, ray, &mesh, scene, mesh_id == -1)) return acc;

					//russian roulette
					float roulettePdf = fmax3(mask);
					if (roulettePdf < 0.1f) {
						if (xi.x < roulettePdf)
							mask = native_divide(mask, roulettePdf);
						else
							break;
					}

					if (++scatters > max_scatters) {
						break;
					}
				}

				ray->origin = ray->origin + ray->dir * (ray->t + EPS);
				ray->normal = ray->dir;
				ray->backside = bounceIsSpecular = false;
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

					++SPEC_BOUNCES;
					bounceIsSpecular = true;
				}
				else {
					if (!ray->backside) {
						ray->origin = ray->pos - ray->normal * EPS;
						if (!get_dist(&ray->t, ray, &mesh, scene, mesh_id == -1)) return acc;
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

						mask *= m_sample.weight;

						if (m_sample.exited) {
							break;
						}

						ray->origin = m_sample.p;
#if 0
						hg_sample_fast(&ray->dir, 0.8f, seed0, seed1);
#else
						ray->dir = uniformSphere((float2)(get_random(seed0, seed1), get_random(seed0, seed1)));
#endif

						if (!get_dist(&ray->t, ray, &mesh, scene, mesh_id == -1)) return acc;

						//russian roulette
						float roulettePdf = fmax3(mask);
						if (roulettePdf < 0.1f) {
							if (get_random(seed0, seed1) < roulettePdf)
								mask = native_divide(mask, roulettePdf);
							else
								break;
						}

						if (++scatters > max_scatters) {
							break;
						}
					}

					ray->origin = ray->origin + ray->dir * (ray->t + EPS);
					ray->normal = ray->dir;
					ray->backside = bounceIsSpecular = false;
				}
			}

#ifdef HAS_LIGHTS
			if (!bounceIsSpecular) {
				float3 wi;
				for (uint i = 0; i < LIGHT_COUNT; ++i) {
					uint index = LIGHT_INDICES[i];

					if (fast_distance(ray->origin, scene->meshes[index].pos) >= INF) continue;

					float3 dLight = calcDirectLight(ray, scene, &index, &wi, seed0, seed1, mesh_id);
					acc.xyz += dLight * mask * fmax(0.01f, dot(fast_normalize(wi), ray->normal));
				}
			}
#endif

		}
#ifdef GLOBAL_MEDIUM
		else {
			ray->origin = gm_sample.p;

#ifdef HAS_LIGHTS
			float3 vwi;
			for (uint i = 0; i < LIGHT_COUNT; ++i) {
				uint index = LIGHT_INDICES[i];

				if (fast_distance(ray->origin, scene->meshes[index].pos) >= INF) continue;

				float3 dLight = calcDirectLight(ray, scene, &index, &vwi, seed0, seed1, mesh_id);
				// @ToFix - im 100% sure this is wrong
				acc.xyz += dLight * hg_eval(ray->dir, fast_normalize(vwi), gm_hg_g) * mask * exp(-(fast_length(vwi)+gm_sample.t)*g_medium.sigmaT);
			}
#endif

			/* Henyey-Greenstein phase function */
			PhaseSample p_sample;
			hg_sample(ray->dir, gm_hg_g, &p_sample, seed0, seed1);
			ray->dir = p_sample.w;
		}
#endif

		/* terminate if necessary */
		if (DIFF_BOUNCES >= MAX_DIFF_BOUNCES || 
			SPEC_BOUNCES >= MAX_SPEC_BOUNCES ||
			TRANS_BOUNCES >= MAX_TRANS_BOUNCES || 
			SCATTERING_EVENTS >= MAX_SCATTERING_EVENTS
		) { 
			break;
		}

		//russian roulette
		float roulettePdf = fmax3(mask);
		if (roulettePdf < 0.1f && bounce > 2) {
			if (get_random(seed0, seed1) < roulettePdf)
				mask /= roulettePdf;
			else
				break;
		}

		if (!intersect_scene(ray, &mesh_id, scene)) {
			/* cosine weighted importance sampling */
			if (!bounceIsSpecular)
				mask *= fmax(0.01f, dot(ray->dir, ray->normal));

			acc.xyz += mask * read_imagef(env_map, samplerA, envMapEquirect(ray->dir)).xyz;

			break;
		}

#ifdef ALPHA_TESTING
		acc.w = 1.0f;
#endif

	} while(++bounce < MAX_BOUNCES);

	return acc;
}

#endif

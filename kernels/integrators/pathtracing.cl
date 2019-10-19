#ifndef __INTEGRATOR__
#define __INTEGRATOR__

__constant bool enableLightSampling			= true;
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
	
	SurfaceScatterEvent surfaceEvent;

	float alpha = 1.0f;
	float3 emmision = (float3)(0.0f);
#define acc (float4)(emmision, alpha)

	float brdfPdf = 1.0f;

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
	sampleDistance(ray, &gm_sample, &g_medium, seed0, seed1);
	rlh->mask *= gm_sample.weight;
	
	if (++rlh->media.scatters < 1024 && !gm_sample.exited){
		ray->origin = gm_sample.p;

		rlh->bounce.isSpecular = !(enableVolumeLightSampling && (lowOrderScattering || rlh->media.scatters > 1));

#if 0
		/* Henyey-Greenstein phase function */
		PhaseSample p_sample;
		hg_sample(ray->dir, gm_hg_g, &p_sample, seed0, seed1);
		ray->dir = p_sample.w;
#else 
		ray->dir = uniformSphere((float2)(get_random(seed0, seed1), get_random(seed0, seed1)));
#endif
		// @ToDo clear this thing out, fix the light sampling code!!!!!!!
		ray->normal = ray->dir;
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

		surfaceEvent = makeLocalScatterEvent(ray, scene);

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
		{
			if (!Conductor(ray, &surfaceEvent, &mat, seed0, seed1)){
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
			if (!RoughConductor(GGX, ray, &surfaceEvent, &mat, seed0, seed1)){
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
			if (!DielectricBSDF(ray, &surfaceEvent, &mat, seed0, seed1)){
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
			if (!RoughDielectricBSDF(BECKMANN, ray, &surfaceEvent, &mat, seed0, seed1)){
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
#endif
		/*-------------------- VOL --------------------*/
#ifdef VOL
		else if (mat.t & VOL) 
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
			rlh->bounce.isSpecular = !(enableVolumeLightSampling && (lowOrderScattering || rlh->media.scatters > 1));
#else
			rlh->bounce.isSpecular = ray->backside;
#endif
		}
#endif
		/*-------------------- TRANS --------------------
		else if (mat.t & TRANS) {

		}
		/*-------------------- SPECSUB --------------------*/
#ifdef SPECSUB		// SPECSUB
		else if (mat.t & SPECSUB)
		{
			if (!ray->backside) {
				if(get_random(seed0, seed1) < schlick(ray->dir, ray->normal, 1.0f, 1.4f)){
					ray->origin = ray->pos + ray->normal * EPS;
					ray->dir = fast_normalize(reflect(ray->dir, ray->normal));

					++rlh->bounce.spec;
					rlh->bounce.isSpecular = true;
				}
				else {
					ray->origin = ray->pos - ray->normal * EPS;
					if (!get_dist(&ray->t, ray, &mesh, scene, rlh->mesh_id == -1)) {
						rlh->bounce.total = 0;
						return acc;	
					}
					ray->backside = true;
				}
			}
			else {
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
				rlh->bounce.isSpecular = !(enableVolumeLightSampling && (lowOrderScattering || rlh->media.scatters > 1));
	#else
				rlh->bounce.isSpecular = ray->backside;
	#endif
			}
		}
#endif		//END OF SPECSUB
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

#ifdef LIGHT
		if (enableLightSampling && !rlh->bounce.isSpecular) {
			float3 wi;
			for (uint i = 0; i < LIGHT_COUNT; ++i) {
				uint index = LIGHT_INDICES[i];

				if (fast_distance(ray->origin, scene->meshes[index].pos) >= INF) continue;

				float3 dLight = calcDirectLight(ray, scene, &index, &wi, seed0, seed1, rlh->mesh_id);
				// emmision += dLight * rlh->mask * hg_eval(ray->dir, fast_normalize(vwi), gm_hg_g) * exp(-(fast_length(vwi)+gm_sample.t)*g_medium.sigmaT);
				emmision += dLight * rlh->mask * fmax(0.01f, dot(fast_normalize(wi), ray->normal));
			}
		}
#endif

	return acc;

#undef acc
}

#endif

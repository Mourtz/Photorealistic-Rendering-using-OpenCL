#ifndef __INTERSECT__
#define __INTERSECT__

//-------------# LIGHTS
#ifdef LIGHT

/* shadow casting */
bool shadow(
	Ray* ray,
	const Scene* scene
){ 
	const float maxDist = ray->t;

#ifdef __BVH__
	Ray temp_ray = *ray;
	if(traverseShadows(scene, ray)){
		*ray = temp_ray;
		return false;
	}
#endif

#ifdef __SPHERE__
	const uint max_sphere_iterations = scene->mesh_count[0];
	for (uint i = 0; i < max_sphere_iterations; ++i) {
		if (intersect_sphere(ray, scene->mesh_pos[i].xyz, scene->mesh_joker[i].s0)) {
			if (ray->t < maxDist) return false;
		}
	}
#endif

#ifdef __SDF__
	/* if there are any sdfs in the scene raymarch them */
	if (scene->mesh_count[1]) {
		if (shadow_sdf(scene, ray, scene->mesh_count)) {
			return false;
		}
	}
#endif

	uint fl = scene->mesh_count[0] + scene->mesh_count[1];

#ifdef __BOX__
	const uint max_box_iterations = scene->mesh_count[2];
	for (uint i = 0; i < max_box_iterations; ++i) {
		const uint idx = fl++;
		if (intersect_box(scene->mesh_pos[idx].xyz, scene->mesh_joker[idx].s012, ray)) {
			if (ray->t < maxDist) return false;
			break; /* K4: Early termination - shadow hit found */
		}
	}
#endif

#ifdef __QUAD__
	const uint max_quad_iterations = scene->mesh_count[3];
	for (uint i = 0; i < max_quad_iterations; ++i, ++fl) {
		if (intersect_quad(
			scene->mesh_joker[fl],
			ray
		)) {
			if (ray->t < maxDist) return false;
			break; /* K4: Early termination - shadow hit found */
		}
	}
#endif

	return true;
}

#endif
//-------------# LIGHTS

/* find the closest intersection in the scene */
bool intersect_scene(
	Ray* ray, 
	int* mesh_id, 
	const Scene* scene
) {
	ray->t = INF;
	*mesh_id = -1;

#ifdef __BVH__
		traverse(scene, ray);
		ray->normal = normalize(ray->normal);
		ray->pos = ray->origin + ray->dir * ray->t;
#endif

#ifdef __SPHERE__
	for (uint i = 0; i < scene->mesh_count[0]; ++i) {
		if (intersect_sphere(ray, scene->mesh_pos[i].xyz, scene->mesh_joker[i].s0)) {
			ray->pos = ray->origin + ray->dir * ray->t;
			ray->normal = fast_normalize(ray->pos - scene->mesh_pos[i].xyz);
			*mesh_id = i;
		}
	}
#endif

#ifdef __SDF__
	/* if there are any sdfs in the scene raymarch them */
	if (scene->mesh_count[1]) {
		if (intersect_sdf(scene, ray, mesh_id, scene->mesh_count)) {
			ray->pos = ray->origin + ray->dir * ray->t;
			ray->normal = calcNormal(scene, (uint)(*mesh_id), ray->pos);
		}
	}
#endif

	uint fl = scene->mesh_count[0] + scene->mesh_count[1];
#ifdef __BOX__
	for (uint i = 0; i < scene->mesh_count[2]; ++i) {
		if (intersect_box(scene->mesh_pos[fl].xyz, scene->mesh_joker[fl].s012, ray)) {
			ray->pos = ray->origin + ray->dir * ray->t;
			*mesh_id = fl;
		}
		++fl;
	}
#endif

#ifdef __QUAD__
	for (uint i = 0; i < scene->mesh_count[3]; ++i) {
		if(intersect_quad(
			scene->mesh_joker[fl],
			ray
		)){
			*mesh_id = fl;
		}
		++fl;
	}
#endif

#if defined DIEL && defined ROUGH_DIEL
	const bool nTrans = (*mesh_id >= 0) ? (loadMaterial(scene, *mesh_id).t & ~(DIEL | ROUGH_DIEL)) : true;
#elif defined DIEL
	const bool nTrans = (*mesh_id >= 0) ? (loadMaterial(scene, *mesh_id).t & ~DIEL) : true;
#elif defined ROUGH_DIEL
	const bool nTrans = (*mesh_id >= 0) ? (loadMaterial(scene, *mesh_id).t & ~ROUGH_DIEL) : true;
#else
	const bool nTrans = true;
#endif

	ray->backside = dot(ray->normal, ray->dir) > 0.0f;
	ray->normal = nTrans && ray->backside ? -ray->normal : ray->normal;

	return ray->t < INF;
}

#endif

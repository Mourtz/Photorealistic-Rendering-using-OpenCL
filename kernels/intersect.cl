#ifndef __INTERSECT__
#define __INTERSECT__

/* Find the closest distance to a specific object */
bool get_dist(float* dist, const Ray* sray, const Mesh* mesh, const Scene* scene, const bool isOBJ){
	Ray temp_ray = *sray;
	temp_ray.t = INF;

	if(isOBJ) {
		traverse(scene, &temp_ray);
	} 
#ifdef __SPHERE__
	else if(mesh->t & SPHERE){ 
		intersect_sphere(&temp_ray, mesh);
	} 
#endif
#ifdef __SDF__
	else if(mesh->t & SDF){ 
		temp_ray.t = fmin(s_map(mesh, temp_ray.origin), temp_ray.t);
	} 
#endif
#ifdef __BOX__
	else if(mesh->t & BOX){ 
		intersect_box(mesh, &temp_ray);
	}
#endif
#ifdef __QUAD__
	else if (mesh->t & QUAD) {
		intersect_quad(mesh, &temp_ray);
	}
#endif

	*dist = temp_ray.t;
	return temp_ray.t < INF;
}

//-------------# LIGHTS
#ifdef LIGHT

/* Hit a specific object and pass the intesection info to the ray */
bool intersect_mesh(Ray* sray, const Mesh* mesh, const Scene* scene, const bool isOBJ) {
	const Ray temp_ray = *sray;

	sray->t = INF;

	if (isOBJ) {
		traverse(scene, sray);
		sray->pos = sray->origin + sray->dir * sray->t;

		sray->backside = dot(sray->normal, sray->dir) >= 0.0f;
		sray->normal = sray->backside ? -sray->normal : sray->normal;
	}
#ifdef __SPHERE__
	else if (mesh->t & SPHERE) {
		if (intersect_sphere(sray, mesh)) {
			sray->pos = sray->origin + sray->dir * sray->t;
			sray->normal = fast_normalize(sray->pos - mesh->pos);

			//sray->backside = dot(sray->normal, sray->dir) >= 0.0f;
			sray->normal = sray->backside ? -sray->normal : sray->normal;
		}
	}
#endif
#ifdef __SDF__
	else if (mesh->t & SDF) {
		sray->t = fmin(s_map(mesh, sray->origin), sray->t);
		sray->pos = sray->origin + sray->dir * sray->t;
		sray->normal = calcNormal(mesh, sray->pos);

		sray->backside = dot(sray->normal, sray->dir) >= 0.0f;
		sray->normal = sray->backside ? -sray->normal : sray->normal;
	}
#endif
#ifdef __BOX__
	else if (mesh->t & BOX) {
		intersect_box(mesh, sray);
		sray->pos = sray->origin + sray->dir * sray->t;
	}
#endif
#ifdef __QUAD__
	else if (mesh->t & QUAD) {
		intersect_quad(mesh, sray);
	}
#endif

	if (sray->t >= INF) {
		*sray = temp_ray;
		return false;
	}
	return true;
}

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
	for (uint i = 0; i < scene->mesh_count[0]; ++i) {

		Mesh sphere = scene->meshes[i]; /* local copy */

		if (intersect_sphere(ray, &sphere)) {
			if (ray->t < maxDist) return false;
		}
	}
#endif

#ifdef __SDF__
	/* if there are any sdfs in the scene raymarch them */
	if (scene->mesh_count[1]) {
		if (shadow_sdf(scene->meshes, ray, scene->mesh_count)) {
			return false;
		}
	}
#endif

	uint fl = scene->mesh_count[0] + scene->mesh_count[1];
#ifdef __BOX__
	for (uint i = 0; i < scene->mesh_count[2]; ++i) {
		
		Mesh box = scene->meshes[fl++]; /* local copy */

		if (intersect_box(&box, ray)) {
			if (ray->t < maxDist) return false;
		}
	}
#endif

#ifdef __QUAD__
	for (uint i = 0; i < scene->mesh_count[3]; ++i) {
	
		Mesh tquad = scene->meshes[fl++]; /* local copy */

		if (intersect_quad(&tquad, ray)) {
			if (ray->t < maxDist) return false;
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

		Mesh sphere = scene->meshes[i]; /* local copy */

		if (intersect_sphere(ray, &sphere)) {
			ray->pos = ray->origin + ray->dir * ray->t;
			ray->normal = fast_normalize(ray->pos - sphere.pos);
			*mesh_id = i;
		}
	}
#endif

#ifdef __SDF__
	/* if there are any sdfs in the scene raymarch them */
	if (scene->mesh_count[1]) {
		if (intesect_sdf(scene->meshes, ray, mesh_id, scene->mesh_count)) {
			ray->pos = ray->origin + ray->dir * ray->t;
			Mesh sdf = scene->meshes[*mesh_id]; /* local copy */
			ray->normal = calcNormal(&sdf, ray->pos);
		}
	}
#endif

	uint fl = scene->mesh_count[0] + scene->mesh_count[1];
#ifdef __BOX__
	for (uint i = 0; i < scene->mesh_count[2]; ++i) {
		
		Mesh box = scene->meshes[fl]; /* local copy */

		if (intersect_box(&box, ray)) {
			ray->pos = ray->origin + ray->dir * ray->t;
			*mesh_id = fl;
		}
		++fl;
	}
#endif

#ifdef __QUAD__
	for (uint i = 0; i < scene->mesh_count[3]; ++i) {
		
		Mesh tquad = scene->meshes[fl]; /* local copy */

		if(intersect_quad(&tquad, ray)){
			*mesh_id = fl;
		}
		++fl;
	}
#endif

#if defined DIEL && defined ROUGH_DIEL
	const bool nTrans = scene->meshes[*mesh_id].mat.t & ~(DIEL | ROUGH_DIEL);
#elif defined DIEL
	const bool nTrans = scene->meshes[*mesh_id].mat.t & ~DIEL;
#elif defined ROUGH_DIEL
	const bool nTrans = scene->meshes[*mesh_id].mat.t & ~ROUGH_DIEL;
#else
	const bool nTrans = true;
#endif

	ray->backside = dot(ray->normal, ray->dir) > 0.0f;
	ray->normal = nTrans && ray->backside ? -ray->normal : ray->normal;

	return ray->t < INF;
}

#endif

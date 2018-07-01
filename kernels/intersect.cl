#ifndef __INTERSECT__
#define __INTERSECT__

#INC_SDF#
#INC_BOX#
#INC_SPHERE#
#INC_QUAD#
#FILE:geometry/aabb.cl
#FILE:geometry/triangle.cl
#FILE:geometry/bvh.cl

/* Find the closest distance to a specific object */
bool get_dist(float* dist, const Ray* sray, const Mesh* mesh, const Scene* scene, const bool isOBJ){
	Ray temp_ray = *sray;
	temp_ray.t = INF;

	if(isOBJ && scene->NUM_NODES) {
		traverse(scene, &temp_ray);
	} 
#ifdef __SPHERE__
	else if(mesh->t & SPHERE){ 
		float hit_dist = 0.0f;
		if (intersect_sphere(&temp_ray, &hit_dist, mesh)) {
			temp_ray.t = hit_dist;
		}
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

//-------------# HAS_LIGHTS
#ifdef HAS_LIGHTS

/* Hit a specific object and pass the intesection info to the ray */
bool intersect_mesh(Ray* sray, const Mesh* mesh, const Scene* scene, const bool isOBJ) {
	const Ray temp_ray = *sray;

	sray->t = INF;

	if (isOBJ && scene->NUM_NODES) {
		traverse(scene, sray);
		sray->pos = sray->origin + sray->dir * sray->t;

		sray->backside = dot(sray->normal, sray->dir) >= 0.0f;
		sray->normal = sray->backside ? -sray->normal : sray->normal;
	}
#ifdef __SPHERE__
	else if (mesh->t & SPHERE) {
		float hit_dist = 0.0f;
		if (intersect_sphere(sray, &hit_dist, mesh)) {
			sray->t = hit_dist;
			sray->pos = sray->origin + sray->dir * sray->t;
			sray->normal = fast_normalize(sray->pos - mesh->pos);

			sray->backside = dot(sray->normal, sray->dir) >= 0.0f;
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

#ifdef VOLUME_CAUSTICS

/* sample caustics for light tracing */
bool sampleCaustics(Ray* ray, 
	const Mesh* mesh, const Scene* scene, 
	const bool isOBJ, uint* seed0, uint* seed1
) {
	const float nc = 1.0f;
	const float nt = 1.5f;
	const float nnt = ray->backside ? nt / nc : nc / nt;
	
	float3 tdir = refract(ray->dir, ray->normal, nnt);

	/* reflect */
	if (dot(tdir, tdir) == 0.0f || get_random(seed0, seed1) < fresnel(ray->dir, ray->normal, nc, nt, tdir)) {
		return false;
	}
	/* refract */
	else {
		ray->origin = ray->pos - ray->normal * EPS;
		ray->dir = fast_normalize(tdir);
		if (ray->backside) {
			return true;
		}
		else {
			if (!intersect_mesh(ray, mesh, scene, isOBJ)) return false;
			tdir = refract(ray->dir, ray->normal, nnt);

			if (dot(tdir, tdir) == 0.0f || get_random(seed0, seed1) < fresnel(ray->dir, ray->normal, nc, nt, tdir)) {
				return false;
			}
			else {
				return !ray->backside;
			}
		}
	}
}

#endif

/* shadow casting */
bool shadow(
	const Ray* ray,
	const Scene* scene
){ 
	const float maxDist = ray->t;

#ifdef __BVH__
	if (scene->NUM_NODES) {
		traverseShadows(scene, ray);
		if (ray->t < maxDist) return false;
	}
#endif


#ifdef __SPHERE__
	for (uint i = 0; i < scene->mesh_count[0]; ++i) {
		float hit_dist = 0.0f;

		Mesh sphere = scene->meshes[i]; /* local copy */

		if (intersect_sphere(ray, &hit_dist, &sphere)) {
			if (hit_dist < maxDist) return false;
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
//-------------# HAS_LIGHTS

/* find the closest intersection in the scene */
bool intersect_scene(
	Ray* ray, 
	int* mesh_id, 
	const Scene* scene
) {
	ray->t = INF;
	ray->incomingRayDir = -ray->dir;

	*mesh_id = -1;
	bool checkSide = true;

#ifdef __BVH__
	if (scene->NUM_NODES) {
		traverse(scene, ray);

		ray->pos = ray->origin + ray->dir * ray->t;
	}
#endif

#ifdef __SPHERE__
	for (uint i = 0; i < scene->mesh_count[0]; ++i) {
		float hit_dist = 0.0f;

		Mesh sphere = scene->meshes[i]; /* local copy */

		if (intersect_sphere(ray, &hit_dist, &sphere)) {
			ray->t = hit_dist;
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
			checkSide = false;
		}
		++fl;
	}
#endif

#ifdef __QUAD__
	for (uint i = 0; i < scene->mesh_count[3]; ++i) {
		
		Mesh tquad = scene->meshes[fl]; /* local copy */

		if(intersect_quad(&tquad, ray)){
			*mesh_id = fl;
			checkSide = false;
		}
		++fl;
	}
#endif

	if(ray->t < INF){ 
		bool nTrans = scene->meshes[*mesh_id].mat.t & ~REFR;

		ray->backside = dot(ray->normal, ray->dir) >= 0.0f;
		ray->normal = ray->backside && nTrans ? -ray->normal : ray->normal;

		ray->tf = createTangentFrame(&ray->normal);
		return true;
	}

	return false;
}

#endif

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
bool get_dist(float* dist, const Ray* sray, __constant Mesh* mesh, const Scene* scene, const bool isOBJ){
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

/* Hit a specific object and pass the intesection info to the ray */
bool intersect_mesh(Ray* sray, __constant Mesh* mesh, const Scene* scene, const bool isOBJ) {
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

#if defined(VOLUME_CAUSTICS)

/* sample caustics for light tracing */
bool sampleCaustics(Ray* ray, 
	__constant Mesh* mesh, const Scene* scene, 
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

/* shadow raycasting through refractive surfaces */
bool shadow_with_caustics(
	__constant Mesh* meshes,
	const Ray* ray,
	const uint* mesh_count,
	const Scene* scene,
	uint* seed0, uint* seed1
) { 
	Ray sRay = *ray;
	const float maxDist = ray->t;

#ifdef __BVH__
	if (scene->NUM_NODES) {
		if (scene->mat->t & REFR) {
			traverse(scene, &sRay);
			if (sRay.t < maxDist) {
				sRay.pos = sRay.dir * sRay.t + sRay.origin;

				sRay.backside = dot(sRay.normal, sRay.dir) >= 0.0f;
				sRay.normal = sRay.backside ? -sRay.normal : sRay.normal;
				if (!sampleCaustics(&sRay, NULL, scene, true, seed0, seed1)) return false;
			}
		}
		else {
			traverseShadows(scene, &sRay);
			if (sRay.t < maxDist) return false;
		}
	}
#endif


#ifdef __SPHERE__
	for (uint i = 0; i < mesh_count[0]; ++i) {
		float hit_dist = 0.0f;
		if (intersect_sphere(&sRay, &hit_dist, &meshes[i])) {
			if (hit_dist < maxDist){
				if (meshes[i].mat.t & REFR) {
					sRay.t = hit_dist;
					sRay.pos = sRay.origin + sRay.dir * sRay.t;
					sRay.normal = fast_normalize(sRay.pos - meshes[i].pos);

					sRay.backside = dot(sRay.normal, sRay.dir) >= 0.0f;
					sRay.normal = sRay.backside ? -sRay.normal : sRay.normal;
					if (!sampleCaustics(&sRay, &meshes[i], scene, false, seed0, seed1)) return false;
				}
				else {
					return false;
				}
			}
		}
	}
#endif

	uint fl = mesh_count[0] + mesh_count[1];
#ifdef __SDF__
	for (uint i = mesh_count[0]; i < fl; ++i) {
		if (s_map(&meshes[i], sRay.origin) < maxDist) return false;
	}
#endif

#ifdef __BOX__
	for (uint i = 0; i < mesh_count[2]; ++i) {

		if (intersect_box(&meshes[fl], &sRay)) {
			if (sRay.t < maxDist) return false;
		}
		fl++;
	}
#endif

#ifdef __QUAD__
	for (uint i = 0; i < mesh_count[3]; ++i) {
		if (intersect_quad(&meshes[fl], &sRay)) {
			if (sRay.t < maxDist) return false;
		}
		fl++;
	}
#endif

	return true;
}

#endif

/* shadow casting */
bool shadow(
	__constant Mesh* meshes,
	const Ray* ray,
	const uint* mesh_count,
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
	for (uint i = 0; i < mesh_count[0]; ++i) {
		float hit_dist = 0.0f;
		if (intersect_sphere(ray, &hit_dist, &meshes[i])) {
			if (hit_dist < maxDist) return false;
		}
	}
#endif

#ifdef __SDF__
	/* if there are any sdfs in the scene raymarch them */
	if (mesh_count[1]) {
		if (shadow_sdf(meshes, ray, mesh_count)) {
			return false;
		}
	}
#endif

	uint fl = mesh_count[0] + mesh_count[1];
#ifdef __BOX__
	for (uint i = 0; i < mesh_count[2]; ++i) {
		if (intersect_box(&meshes[fl++], ray)) {
			if (ray->t < maxDist) return false;
		}
	}
#endif

#ifdef __QUAD__
	for (uint i = 0; i < mesh_count[3]; ++i) {
		if (intersect_quad(&meshes[fl++], ray)) {
			if (ray->t < maxDist) return false;
		}
	}
#endif

	return true;
}

/* find the closest intersection in the scene */
bool intersect_scene(
	__constant Mesh* meshes, 
	Ray* ray, 
	int* mesh_id, 
	const uint* mesh_count, 
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
	for (uint i = 0; i < mesh_count[0]; ++i) {
		float hit_dist = 0.0f;

		if (intersect_sphere(ray, &hit_dist, &meshes[i])) {
			ray->t = hit_dist;
			ray->pos = ray->origin + ray->dir * ray->t;
			ray->normal = fast_normalize(ray->pos - meshes[i].pos);
			*mesh_id = i;
		}
	}
#endif

#ifdef __SDF__
	/* if there are any sdfs in the scene raymarch them */
	if (mesh_count[1]) {
		if (intesect_sdf(meshes, ray, mesh_id, mesh_count)) {
			ray->pos = ray->origin + ray->dir * ray->t;
			ray->normal = calcNormal(&meshes[*mesh_id], ray->pos);
		}
	}
#endif

	uint fl = mesh_count[0] + mesh_count[1];
#ifdef __BOX__
	for (uint i = 0; i < mesh_count[2]; ++i) {
		if (intersect_box(&meshes[fl], ray)) {
			ray->pos = ray->origin + ray->dir * ray->t;
			*mesh_id = fl;
			checkSide = false;
		}
		++fl;
	}
#endif

#ifdef __QUAD__
	for (uint i = 0; i < mesh_count[3]; ++i) {
		if(intersect_quad(&meshes[fl], ray)){
			*mesh_id = fl;
			checkSide = false;
		}
		++fl;
	}
#endif

	if(ray->t < INF){ 
		if (checkSide) {
			ray->backside = dot(ray->normal, ray->dir) >= 0.0f;
			ray->normal = ray->backside ? -ray->normal : ray->normal;
		}
		ray->tf = createTangentFrame(&ray->normal);
		return true;
	}

	return false;
}

#endif

#ifndef __BVH__
#define __BVH__

// aliases
#define traverseShadows traverseShadowsStackless
#define traverse traverseStackless

typedef struct {
	float3 invDir;
	float3 scaled_origin;  // = -ray->origin * invDir
} TraversalRayData;

inline TraversalRayData makeTraversalRayData(const Ray* ray) {
	TraversalRayData data;
	data.invDir = native_recip(ray->dir);
	data.scaled_origin = -ray->origin * data.invDir;
	return data;
}

inline float2 intersectNode(__constant new_bvhNode* node, const Ray* ray, const TraversalRayData* data) {
	float3 t1 = fma(node->bbMin.xyz, data->invDir, data->scaled_origin);
	float3 t2 = fma(node->bbMax.xyz, data->invDir, data->scaled_origin);

	float3 tmin3 = fmin(t1, t2);
	float3 tmax3 = fmax(t1, t2);

	return (float2)(
		fmax(fmax(tmin3.x, tmin3.y), fmax(tmin3.z, EPS)),
		fmin(fmin(tmax3.x, tmax3.y), fmin(tmax3.z, ray->t))
	);
}

bool intersectLeafShadows(const Scene* scene, 
	__constant new_bvhNode* node, 
	Ray* ray){

	uint begin = node->first_child_or_primitive;
	uint end = begin + node->primitive_count;
	
	for(uint i = begin; i < end; ++i){
		if(intersectTriangle(scene, ray, i))
			return true;
	}
	return false;
}

bool traverseShadowsStackless(const Scene* scene, Ray* ray) {
	uint current_node_idx = 0;
	const TraversalRayData rayData = makeTraversalRayData(ray);

	while(current_node_idx != UINT_MAX) {
		__constant new_bvhNode* current_node = &scene->new_nodes[current_node_idx];
		float2 t_bounds = intersectNode(current_node, ray, &rayData);

		if(t_bounds.x > t_bounds.y) {
			current_node_idx = current_node->miss_link;
			continue;
		}

		if(current_node->primitive_count != 0) {
			if(intersectLeafShadows(scene, current_node, ray)) {
				return true;
			}
			current_node_idx = current_node->miss_link;
		} else {
			current_node_idx = current_node->first_child_or_primitive;
		}
	}

	return false;
}

bool intersectLeaf(const Scene* scene, 
	__constant new_bvhNode* node, 
	Ray* ray){

	uint begin = node->first_child_or_primitive;
	uint end = begin + node->primitive_count;
	
	bool res = false;
	for(uint i = begin; i < end; ++i){
		res |= intersectTriangle(scene, ray, i);
	}
	return res;
}

bool traverseStackless(const Scene* scene, Ray* ray) {
	uint current_node_idx = 0;
	bool found_intersection = false;
	const TraversalRayData rayData = makeTraversalRayData(ray);

	while(current_node_idx != UINT_MAX) {
		__constant new_bvhNode* current_node = &scene->new_nodes[current_node_idx];

		float2 t_bounds = intersectNode(current_node, ray, &rayData);

		if(t_bounds.x > t_bounds.y) {
			current_node_idx = current_node->miss_link;
			continue;
		}

		if(current_node->primitive_count != 0) {
			if(intersectLeaf(scene, current_node, ray)) {
				found_intersection = true;
			}
			current_node_idx = current_node->miss_link;
		} else {
			current_node_idx = current_node->first_child_or_primitive;
		}
	}

	return found_intersection;
}


#endif

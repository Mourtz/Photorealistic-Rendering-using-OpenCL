#ifndef __BVH__
#define __BVH__

// aliases
#define traverseShadows traverseShadowsStackless
#define traverse traverseStackless


float intersectAxis(int axis, const float p, const Ray* ray){
	const float3 invDir = native_recip(ray->dir);
	const float3 scaled_origin = -ray->origin*invDir;

	return fma(p, ((float*)(&invDir))[axis], ((float*)(&scaled_origin))[axis]);
}

float2 intersectNode(__constant new_bvhNode* node, const Ray* ray){
	int3 octant = (int3)(ray->dir.x < 0.0f, ray->dir.y < 0.0f, ray->dir.z < 0.0f);
	
	float entry0 = intersectAxis(0, node->bounds[0 * 2 + octant.x], ray);
	float entry1 = intersectAxis(1, node->bounds[1 * 2 + octant.y], ray);
	float entry2 = intersectAxis(2, node->bounds[2 * 2 + octant.z], ray);

	float exit0 = intersectAxis(0, node->bounds[0 * 2 + 1 - octant.x], ray);
	float exit1 = intersectAxis(1, node->bounds[1 * 2 + 1 - octant.y], ray);
	float exit2 = intersectAxis(2, node->bounds[2 * 2 + 1 - octant.z], ray);

	return (float2)(
		fmax(entry0, fmax(entry1, fmax(entry2, EPS))),
		fmin(exit0, fmin(exit1, fmin(exit2, ray->t)))
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
	__constant new_bvhNode* current_node = &scene->new_nodes[current_node_idx];
	
	while(current_node_idx != UINT_MAX) {
		current_node = &scene->new_nodes[current_node_idx];
		
		float2 t_bounds = intersectNode(current_node, ray);
		
        // Miss - follow miss link
		if(t_bounds.x > t_bounds.y) {
			current_node_idx = current_node->miss_link;
			continue;
		}
		
		if(current_node->isLeaf) {
			if(intersectLeafShadows(scene, current_node, ray)) {
				return true;
			}
			current_node_idx = current_node->miss_link;
		} else {
			current_node_idx = current_node->first_child_or_primitive;
		}
	}
	
	return false; // No intersection found
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
	__constant new_bvhNode* current_node;
	bool found_intersection = false;
	
	while(current_node_idx != UINT_MAX) {
		current_node = &scene->new_nodes[current_node_idx];
		
		float2 t_bounds = intersectNode(current_node, ray);
		
        // Miss - follow miss link
		if(t_bounds.x > t_bounds.y) {
			current_node_idx = current_node->miss_link;
			continue;
		}
		
		if(current_node->isLeaf) {
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
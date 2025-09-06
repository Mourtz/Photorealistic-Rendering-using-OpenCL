#ifndef __BVH__
#define __BVH__

/*
 * BVH Traversal Optimization
 * 
 * This file implements both traditional stack-based and stackless BVH traversal algorithms.
 * 
 * Stackless traversal benefits:
 * - Reduced memory usage (no explicit stack allocation)
 * - Better performance on GPUs with limited stack depth
 * - Avoids stack overflow issues in deep trees
 * - Uses restart-based approach to handle multiple children
 * 
 * Configuration:
 * - Set USE_STACKLESS_TRAVERSAL to 1 for stackless traversal
 * - Set USE_STACKLESS_TRAVERSAL to 0 for traditional stack-based traversal
 */

// Configuration: Enable stackless traversal (faster on modern GPUs with limited stack)
#define USE_STACKLESS_TRAVERSAL 1

// Constants
#define UINT_MAX 0xFFFFFFFF
#define MAX_BVH_NODES 100000

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

// Restart-based stackless traversal for shadow rays
bool traverseShadowsStackless(const Scene* scene, Ray* ray) {
	uint restart_node = 0;
	
	while(restart_node != UINT_MAX) {
		uint node_index = restart_node;
		restart_node = UINT_MAX; // Will be set if we need to restart
		
		// Traverse from restart_node down to leaves
		while(true) {
			__constant new_bvhNode* node = &scene->new_nodes[node_index];
			
			if(node->isLeaf) {
				if(intersectLeafShadows(scene, node, ray)) {
					return true; // Early exit for shadow rays
				}
				break; // Done with this path
			}
			
			// Inner node - check children
			uint first_child = node->first_child_or_primitive;
			__constant new_bvhNode* left_child = &scene->new_nodes[first_child + 0];
			__constant new_bvhNode* right_child = &scene->new_nodes[first_child + 1];
			
			float2 dist_left = intersectNode(left_child, ray);
			float2 dist_right = intersectNode(right_child, ray);
			
			bool hit_left = (dist_left.x <= dist_left.y);
			bool hit_right = (dist_right.x <= dist_right.y);

			if(hit_left && hit_right) {
				// Both hit - visit closer one first, restart from farther one
				if(dist_left.x <= dist_right.x) {
					restart_node = first_child + 1; // Restart from right child later
					node_index = first_child;       // Continue with left child
				} else {
					restart_node = first_child;     // Restart from left child later  
					node_index = first_child + 1;   // Continue with right child
				}
			} else if(hit_left) {
				node_index = first_child; // Continue with left child
			} else if(hit_right) {
				node_index = first_child + 1; // Continue with right child
			} else {
				break; // Neither hit - done with this path
			}
		}
	}
	
	return false;
}

// Restart-based stackless traversal for closest hit rays
bool traverseStackless(const Scene* scene, Ray* ray) {
	uint restart_node = 0;
	bool hit_found = false;
	
	while(restart_node != UINT_MAX) {
		uint node_index = restart_node;
		restart_node = UINT_MAX; // Will be set if we need to restart
		
		// Traverse from restart_node down to leaves
		while(true) {
			__constant new_bvhNode* node = &scene->new_nodes[node_index];
			
			if(node->isLeaf) {
				if(intersectLeaf(scene, node, ray)) {
					hit_found = true;
					if(ray->t <= EPS)
						return true;
				}
				break; // Done with this path
			}
			
			// Inner node - check children
			uint first_child = node->first_child_or_primitive;
			__constant new_bvhNode* left_child = &scene->new_nodes[first_child + 0];
			__constant new_bvhNode* right_child = &scene->new_nodes[first_child + 1];
			
			float2 dist_left = intersectNode(left_child, ray);
			float2 dist_right = intersectNode(right_child, ray);
			
			bool hit_left = (dist_left.x <= dist_left.y);
			bool hit_right = (dist_right.x <= dist_right.y);

			if(hit_left && hit_right) {
				// Both hit - visit closer one first, restart from farther one
				if(dist_left.x <= dist_right.x) {
					restart_node = first_child + 1; // Restart from right child later
					node_index = first_child;       // Continue with left child
				} else {
					restart_node = first_child;     // Restart from left child later  
					node_index = first_child + 1;   // Continue with right child
				}
			} else if(hit_left) {
				node_index = first_child; // Continue with left child
			} else if(hit_right) {
				node_index = first_child + 1; // Continue with right child
			} else {
				break; // Neither hit - done with this path
			}
		}
	}
	
	return hit_found;
}

// Helper function to check if a node index represents a left child
bool isLeftChild(uint node_index) {
	if(node_index == 0) return false; // Root is neither left nor right
	return (node_index & 1) == 1; // Left children have odd indices
}

// Helper function to get parent index from child index
uint getParentIndex(uint child_index) {
	if(child_index == 0) return 0; // Root has no parent
	return (child_index - 1) / 2;
}

// Helper function to get next node index in traversal order
uint getNextNodeIndex(uint current_index) {
	if(current_index == 0) return 0; // Root has no next
	
	// If this is a left child (odd index), try the right sibling
	if((current_index & 1) == 1) {
		return current_index + 1;
	}
	
	// If this is a right child (even index), go up to parent and find next
	uint parent_index = (current_index - 2) / 2;
	return getNextNodeIndex(parent_index);
}

#define STACK_SIZE 8
bool traverseShadowsOld(const Scene* scene, Ray* ray) {
	__constant new_bvhNode* stack[STACK_SIZE];
	uchar stackSize = 0;
	
	__constant new_bvhNode* node = &scene->new_nodes[0];

	if(node->isLeaf){
		LOGWARNING("[Warning]: root is a leaf!\n");
		return intersectLeafShadows(scene, node, ray);
	}

	while(true){
		uint first_child = node->first_child_or_primitive;
		__constant new_bvhNode* left_child = 
			&scene->new_nodes[first_child + 0];
		__constant new_bvhNode* right_child = 
			&scene->new_nodes[first_child + 1];
		float2 dist_left = intersectNode(left_child, ray);
		float2 dist_right = intersectNode(right_child, ray);
		
		// left child
		bool l_child = true;
		if(dist_left.x <= dist_left.y){
			if(left_child->isLeaf){
				if(intersectLeafShadows(scene, left_child, ray)){
					return true;
				}
				l_child = false;
			}
		} else {
			l_child = false;
		}

		// right child
		bool r_child = true;
		if(dist_right.x <= dist_right.y){
			if(right_child->isLeaf){
				if(intersectLeafShadows(scene, right_child, ray)){
					return true;
				}
				r_child = false;
			}
		} else {
			r_child = false;
		}

		if(l_child ^ r_child){
			node = l_child ? left_child : right_child;
		} else if(l_child & r_child){
			if(dist_left.x > dist_right.x){
				__constant new_bvhNode* temp = left_child;
				left_child = right_child;
				right_child = temp;
			}
			stack[stackSize++] = right_child;
			node = left_child;
		} else {
			if(stackSize == 0)
				break;
			node = stack[--stackSize];
		}
	}
#if DEBUG
#if VIEW_OPTION == VIEW_STACK_INDEX
	ray->bvh_stackSize = stackSize;
#endif
	if(stackSize >= STACK_SIZE)
		LOGWARNING("[WARNING]: exceeded max stack size!\n");
#endif

	return false;
}
#undef STACK_SIZE

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

#define STACK_SIZE 64
bool traverseOld(const Scene* scene, Ray* ray) {
	__constant new_bvhNode* stack[STACK_SIZE];
	uchar stackSize = 0;
	
	__constant new_bvhNode* node = &scene->new_nodes[0];

	if(node->isLeaf){
		LOGWARNING("[Warning]: root is a leaf!\n");
		return intersectLeaf(scene, node, ray);
	}


	while(true){
		uint first_child = node->first_child_or_primitive;
		__constant new_bvhNode* left_child = 
			&scene->new_nodes[first_child + 0];
		__constant new_bvhNode* right_child = 
			&scene->new_nodes[first_child + 1];
		float2 dist_left = intersectNode(left_child, ray);
		float2 dist_right = intersectNode(right_child, ray);
		
		// left child
		bool l_child = true;
		if(dist_left.x <= dist_left.y){
			if(left_child->isLeaf){
				if(intersectLeaf(scene, left_child, ray)){
					if(ray->t <= EPS)
						return true;
				}
				l_child = false;
			}
		} else {
			l_child = false;
		}

		// right child
		bool r_child = true;
		if(dist_right.x <= dist_right.y){
			if(right_child->isLeaf){
				if(intersectLeaf(scene, right_child, ray)){
					if(ray->t <= EPS)
						return true;
				}
				r_child = false;
			}
		} else {
			r_child = false;
		}

		if(l_child ^ r_child){
			node = l_child ? left_child : right_child;
		} else if(l_child & r_child){
			if(dist_left.x > dist_right.x){
				__constant new_bvhNode* temp = left_child;
				left_child = right_child;
				right_child = temp;
			}
			stack[stackSize++] = right_child;
			node = left_child;
		} else {
			if(stackSize == 0)
				break;
			node = stack[--stackSize];
		}
	}
#if DEBUG
#if VIEW_OPTION == VIEW_STACK_INDEX
	ray->bvh_stackSize = stackSize;
#endif
	if(stackSize >= STACK_SIZE)
		LOGWARNING("[WARNING]: exceeded max stack size!\n");
#endif

	return false;
}
#undef STACK_SIZE

// Unified traversal functions that choose between stackless and traditional
bool traverseShadowsUnified(const Scene* scene, Ray* ray) {
#if USE_STACKLESS_TRAVERSAL
	return traverseShadowsStackless(scene, ray);
#else
	return traverseShadowsOld(scene, ray);
#endif
}

bool traverseUnified(const Scene* scene, Ray* ray) {
#if USE_STACKLESS_TRAVERSAL
	return traverseStackless(scene, ray);
#else
	return traverseOld(scene, ray);
#endif
}

// For compatibility, redefine the original function names to use unified versions
#define traverseShadows traverseShadowsUnified
#define traverse traverseUnified

#endif
#ifndef __BVH__
#define __BVH__

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
bool traverse(const Scene* scene, Ray* ray) {
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

#endif
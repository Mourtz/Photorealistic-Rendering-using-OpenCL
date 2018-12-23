#pragma OPENCL EXTENSION cl_khr_fp16 : enable

__constant sampler_t samplerA = CLK_NORMALIZED_COORDS_TRUE | CLK_ADDRESS_CLAMP | CLK_FILTER_LINEAR;

#FILE:header.cl
#FILE:utils.cl
#FILE:noise/value_noise.cl
#FILE:camera.cl
#FILE:bxdf/bxdf.cl
#FILE:intersect.cl
#FILE:media.cl
#FILE:integrators/pathtracing.cl

typedef struct {
	float3 origin, dir, mask;
	uint bounce;
} RayI;

__kernel void render_kernel(
	/* scene's Meshes */
	__constant Mesh* meshes,
	
	/* window size */
	const int width, const int height,

	/* total meshes in the scene @ToRemove */
	const uint8 mesh_count,

	/* current frame */
	const uint framenumber, 

	/* camera */
	__constant Camera* cam,

	/* seeds */
	const int random0, const int random1,

	/* accumulation buffer */
	__global float4* accumbuffer,
	
	/* new frame */
	__write_only image2d_t output_tex,
	
	/* BVH */
	const uint BVH_NUM_NODES,
	__constant bvhNode* bvh,
	__constant uint4* facesV,
	__constant uint4* facesN,
	__constant float4* vertices,
	__constant float4* normals,
	__constant Material* mat,

	/* enviroment map */
	__read_only image2d_t env_map,

	__global RayI* r_flat // 0-2: origin, 3-5: dir, 6-8: mask, 9: traces
) {
	const int work_item_id = get_global_id(0);			/* the unique global id of the work item for the current pixel */
	
	/* xy-coordinate of the pixel */
	const int2 i_coord = (int2)(work_item_id % width, work_item_id / width);
	// const float2 f_coord = (float2)((float)(i_coord.x) / width, (float)(i_coord.y) / height);

	uint bounce = r_flat[work_item_id].bounce;
	float3 mask = (float3)(1.0f);

	/* seeds for random number generator */
	uint seed0 = i_coord.x * framenumber % 1000 + bounce*random0;
	uint seed1 = i_coord.y * framenumber % 1000 + bounce*random1;

	// printf("%.1f", mask);
	// bounce *= (bounce <= 32);

	Ray ray;
	if(bounce > 0){
		ray.origin 	= r_flat[work_item_id].origin;
		ray.dir 	= r_flat[work_item_id].dir;
		mask 		= r_flat[work_item_id].mask;
	} else {
		ray = createCamRay(i_coord, width, height, cam, &seed0, &seed1);
	}
	
	const Scene scene = { meshes, &mesh_count, BVH_NUM_NODES, bvh, facesV, facesN, vertices, normals, mat };
	
	/* add pixel colour to accumulation buffer (accumulates all samples) */
	accumbuffer[work_item_id] += radiance(&scene, env_map, &ray, &mask, &bounce, &seed0, &seed1);

	r_flat[work_item_id].bounce = bounce;
	r_flat[work_item_id].origin = ray.origin;
	r_flat[work_item_id].dir= ray.dir;
	r_flat[work_item_id].mask = mask;

	/* update the output GLTexture */
	write_imagef(output_tex, i_coord, accumbuffer[work_item_id] / (0.2f*framenumber));
}
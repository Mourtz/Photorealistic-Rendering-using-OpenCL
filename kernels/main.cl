#pragma OPENCL EXTENSION cl_khr_fp16 : enable

__constant sampler_t samplerA = CLK_NORMALIZED_COORDS_TRUE | CLK_ADDRESS_CLAMP | CLK_FILTER_LINEAR;

#FILE:header.cl
#FILE:utils.cl
#FILE:camera.cl
#FILE:bxdf/bxdf.cl
#FILE:intersect.cl
#FILE:media.cl
#FILE:noise/value_noise.cl
#FILE:integrators/pathtracing.cl

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
	__global float3* accumbuffer,

	/* Wang Hashed framenumber */
	const uint hashedframenumber,
	
	/* new frame */
	__write_only image2d_t output_tex,
	
	/* BVH */
	const uint BVH_NUM_NODES,
	__global const bvhNode* bvh,
	__global const uint4* facesV,
	__global const uint4* facesN,
	__global const float4* vertices,
	__global const float4* normals,
	__constant Material* mat,

	__read_only image2d_t env_map
) {
	int work_item_id = get_global_id(0);			/* the unique global id of the work item for the current pixel */
	/* xy-coordinate of the pixel */
	int2 i_coord = (int2)(work_item_id % width, work_item_id / width);
	float2 f_coord = (float2)((float)(i_coord.x) / width, (float)(i_coord.y) / height);

	/* seeds for random number generator */
	uint seed0 = i_coord.x * framenumber % 1000 + (random0 * 100);
	uint seed1 = i_coord.y * framenumber % 1000 + (random1 * 100);

	const Scene scene = { BVH_NUM_NODES, bvh, facesV, facesN, vertices, normals, mat };

	Ray ray = createCamRay(i_coord, width, height, cam, &seed0, &seed1);
	/* add pixel colour to accumulation buffer (accumulates all samples) */
	accumbuffer[work_item_id] += radiance(meshes, &mesh_count, &scene, env_map, &ray, &seed0, &seed1);
	/* averaged colour: divide colour by the number of calculated frames so far */
	float3 tempcolor = accumbuffer[work_item_id] / (float)(framenumber);

	/* update the output GLTexture */
	write_imagef(output_tex, i_coord, (float4)(tempcolor, 1.0f));
}
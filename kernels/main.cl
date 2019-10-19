#pragma OPENCL EXTENSION cl_khr_fp16 : enable

__constant sampler_t samplerA = CLK_NORMALIZED_COORDS_TRUE | CLK_ADDRESS_CLAMP | CLK_FILTER_LINEAR;

#define RNG_TYPE 2

#if RNG_TYPE == 0
#define RNG_SEED_TYPE uint
#define RNG_SEED_PARAM RNG_SEED_TYPE* seed0, RNG_SEED_TYPE* seed1
#define RNG_SEED_VALUE seed0, seed1
#define RNG_SEED_VALUE_P &seed0, &seed1
#elif RNG_TYPE == 1
#define RNG_SEED_TYPE ulong
#define RNG_SEED_PARAM RNG_SEED_TYPE* state
#define RNG_SEED_VALUE state
#define RNG_SEED_VALUE_P &RNG_SEED_VALUE
#elif RNG_TYPE == 2
#define RNG_SEED_TYPE double
#define RNG_SEED_PARAM RNG_SEED_TYPE* seed
#define RNG_SEED_VALUE seed
#define RNG_SEED_VALUE_P &RNG_SEED_VALUE
#endif

typedef struct {
	// throughput
	float3 mask;
	// accumulation buffer
	float4 acc;

	struct {
		// total bounces
		uint total;
		// explicit light controls
		ushort diff, spec, trans;
		bool isSpecular;
	} bounce;

	// participating medium
	struct {
		bool in;
		ushort scatters;
	} media;

	int mesh_id;
} RLH;

#FILE:header.cl
#FILE:utils.cl
#FILE:noise/value_noise.cl
#FILE:camera.cl
#FILE:bxdf/bxdf.cl
#FILE:intersect.cl
#FILE:media.cl

typedef struct {
	Ray ray;
	RLH data;
} RTD;

#FILE:integrators/base.cl
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

	__global RTD* r_flat
) {
	const int work_item_id = get_global_id(0);			/* the unique global id of the work item for the current pixel */

	/* xy-coordinate of the pixel */
	const int2 i_coord = (int2)(work_item_id % width, work_item_id / width);

	__global RLH* rlh = &r_flat[work_item_id].data;

	const bool firstBounce = (rlh->bounce.total == 0);
	rlh->bounce.total *= !firstBounce;
	rlh->bounce.diff *= !firstBounce;
	rlh->bounce.spec *= !firstBounce;
	rlh->bounce.trans *= !firstBounce;
	rlh->bounce.isSpecular |= firstBounce;
	rlh->media.scatters *= !firstBounce;
	rlh->media.in &= !firstBounce;

	rlh->mask = !firstBounce * rlh->mask + firstBounce;

#if RNG_TYPE == 0
	/* seeds for random number generator */
	uint seed0 = i_coord.x * framenumber % 1000 + (rlh->bounce.total + 33) * random0;
	uint seed1 = i_coord.y * framenumber % 1000 + (rlh->bounce.total + 100) * random1;
#elif RNG_TYPE == 1

#elif RNG_TYPE == 2
	const float2 f_coord = (float2)((float)(i_coord.x) / width, (float)(i_coord.y) / height);
	double seed = dot(f_coord, (float2)(framenumber % 1000 + random0, framenumber % 333 + random1));
#endif

	Ray ray = firstBounce ? createCamRay(i_coord, width, height, cam, RNG_SEED_VALUE_P) : r_flat[work_item_id].ray;

	const Scene scene = { meshes, &mesh_count, BVH_NUM_NODES, bvh, facesV, facesN, vertices, normals, mat };

	/* add pixel colour to accumulation buffer (accumulates all samples) */
	rlh->acc += radiance(&scene, env_map, &ray, rlh, RNG_SEED_VALUE_P);

	r_flat[work_item_id].ray = ray;

	/* update the output GLTexture */
	write_imagef(output_tex, i_coord, rlh->acc / (float)(framenumber));
}
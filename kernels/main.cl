#ifndef __OPENCL_RAYTRACER__
#define __OPENCL_RAYTRACER__

#define DEBUG 1

#define VIEW_RESULTS  		(0)
#define VIEW_NORMAL   		(1<<0)
#define VIEW_STACK_INDEX   	(1<<1)
#define VIEW_ALBEDO			(1<<2)
#define VIEW_SPECULAR       (1<<3)
#define VIEW_BVH_HIT	    (1<<4)

#define VIEW_OPTION (~(0xFF<<(DEBUG*8)) & VIEW_RESULTS) 

#if DEBUG
	#define LOGINFO(x) printf("[Info]: %s\n", x)
	#define LOGWARNING(x) printf("[Warning]: %s\n", x)
	#define LOGERROR(x) printf("[Error]: %s\n", x)
	#define LOGPROFILING(x) printf("[Profiling]: %s\n", x)
#else
	#define LOGINFO(x)
	#define LOGWARNING(x)
	#define LOGERROR(x)
	#define LOGPROFILING(x)
#endif

#pragma OPENCL EXTENSION cl_khr_fp16 : enable

__constant sampler_t samplerA = CLK_NORMALIZED_COORDS_TRUE | CLK_ADDRESS_CLAMP | CLK_FILTER_LINEAR;

#define tempToRay(tray) (Ray){ tray.origin, tray.dir, (float3)(0.0f), (float3)(0.0f), {tray.dist}, false, tray.time }
#define rayToTemp(ray) (TempRay){ ray.origin, ray.dir, ray.t, ray.time }

typedef struct {
	// throughput
	float3 mask;
	// accumulation buffer
	float4 acc;

	struct {
		// total bounces
		uint total;
		// explicit light controls
		ushort diff, spec, trans, scatters;
		bool wasSpecular;
	} bounce;

	bool reset;
	uint samples;
	//int mesh_id;
} RLH;

#FILE:header.cl
#FILE:utils.cl
#FILE:noise/value_noise.cl
#FILE:camera.cl
#FILE:geometry/geometry.cl
#FILE:intersect.cl
#FILE:bxdf/bxdf.cl
#FILE:media.cl

typedef struct {
	TempRay ray;
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
	__constant uint* primitive_indices,
	__constant float4* vertices,
	__constant float4* normals,
	__constant Material* mat,

	/* enviroment map */
	__read_only image2d_t env_map,

	__global RTD* r_flat,

	__constant new_bvhNode* new_bvh_node
) {
	const int work_item_id = get_global_id(0);			/* the unique global id of the work item for the current pixel */

	/* xy-coordinate of the pixel */
	const int2 i_coord = (int2)(work_item_id % width, work_item_id / width);

#if RNG_TYPE == 0
	/* seeds for random number generator */
	uint seed0 = i_coord.x * framenumber % 1000 + (random0 * 100);
	uint seed1 = i_coord.y * framenumber % 1000 + (random1 * 100);
#elif RNG_TYPE == 1
	ulong state = 0xBA5EBA11;
#elif RNG_TYPE == 2
	const float2 f_coord = (float2)((float)(i_coord.x) / width, (float)(i_coord.y) / height);
	double seed = dot(f_coord, (float2)(framenumber % 1000 + random0 * 100, framenumber % 333 + random1 * 33));
#endif

	__global RLH* rlh = &r_flat[work_item_id].data;

	Ray ray = tempToRay(r_flat[work_item_id].ray);

	// firstBounce or reset
	if (rlh->reset || rlh->samples == 0) {
		++rlh->samples;
		rlh->bounce.total = 0;
		rlh->bounce.diff = 0;
		rlh->bounce.spec = 0;
		rlh->bounce.trans = 0;
		rlh->bounce.scatters = 0;
		rlh->bounce.wasSpecular = true;
		rlh->reset = false;

		rlh->mask = (float3)(1.0f);

		// @ToDo generate cam ray on CPU
		ray = createCamRay(i_coord, width, height, cam, RNG_SEED_VALUE_P);
	}

	const Scene scene = { meshes, primitive_indices, new_bvh_node, &mesh_count, vertices, normals, mat };

#if VIEW_OPTION == VIEW_RESULTS
	/* add pixel colour to accumulation buffer (accumulates all samples) */
	rlh->acc += radiance(&scene, env_map, &ray, rlh, RNG_SEED_VALUE_P);
#elif VIEW_OPTION == VIEW_NORMAL
	radiance(&scene, env_map, &ray, rlh, RNG_SEED_VALUE_P);
	rlh->acc = (float4)(ray.normal, 1.0f);
#elif VIEW_OPTION == VIEW_STACK_INDEX
	radiance(&scene, env_map, &ray, rlh, RNG_SEED_VALUE_P);
	// rlh->acc = (float4)((float3)((float)(64-ray.bvh_stackIndex)/64.0f), 1.0f);
	rlh->acc = (float4)((float3)(fmin(1.0f, (float)(ray.bvh_stackIndex))), 1.0f);
#elif VIEW_OPTION == VIEW_BVH_HIT
	radiance(&scene, env_map, &ray, rlh, RNG_SEED_VALUE_P);
	rlh->acc = (float4)(ray.normal, 1.0f);
#endif

	r_flat[work_item_id].ray = rayToTemp(ray);

	/* update the output GLTexture */
#if VIEW_OPTION == VIEW_RESULTS
	write_imagef(output_tex, i_coord, rlh->acc / (float)(rlh->samples));
#else
	write_imagef(output_tex, i_coord, rlh->acc);
#endif
}

#endif
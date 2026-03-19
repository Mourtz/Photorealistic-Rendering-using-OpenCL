#ifndef __OPENCL_RAYTRACER__
#define __OPENCL_RAYTRACER__

#define DEBUG 0

#define MAT_TEX_SIZE 1024

#define BOUNCES_PER_FRAME 4

#define VIEW_RESULTS  		(0)
#define VIEW_NORMAL   		(1<<0)
#define VIEW_STACK_INDEX   	(1<<1)
#define VIEW_ALBEDO			(1<<2)
#define VIEW_SPECULAR       (1<<3)
#define VIEW_BVH_HIT	    (1<<4)

#define VIEW_OPTION (~(0xFF<<(DEBUG*8)) & VIEW_RESULTS) 

#if DEBUG
	#define LOGWARNING(x) printf(x);
	#define LOGERROR(x) printf(x);
#else
	#define LOGERROR(x)
	#define LOGWARNING(x)
#endif

#pragma OPENCL EXTENSION cl_khr_fp16 : enable

__constant sampler_t samplerA = CLK_NORMALIZED_COORDS_TRUE | CLK_ADDRESS_CLAMP | CLK_FILTER_LINEAR;


typedef struct {
	// throughput
	float3 mask;
	// accumulation buffer
	float4 acc;

	// PDF of the last BSDF scatter — used for MIS against env-map IS
	float last_bsdf_pdf;

	struct {
		// total bounces
		uint total;
		// explicit light controls
		ushort diff, spec, trans, scatters;
		bool wasSpecular;
	} bounce;

	bool reset;
	uint samples;
} RLH;

#FILE:header.cl
#FILE:utils.cl
#FILE:noise/value_noise.cl
#FILE:camera.cl
#FILE:geometry/geometry.cl
#FILE:intersect.cl
#FILE:bxdf/bxdf.cl
#FILE:media.cl

#FILE:envmap_is.cl
#FILE:integrators/base.cl
#FILE:integrators/pathtracing.cl

__kernel void render_kernel(
	/* scene mesh SoA */
	__constant Material* mesh_mats,
	__constant float4* mesh_pos,
	__constant float16* mesh_joker,
	__constant uchar* mesh_type,

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

	/* enviroment map */
	__read_only image2d_t env_map,

	/* SoA per-pixel path state — coalesced float4/uint4 access replaces AoS RTD */
	__global float4* soa_ray_org_t,        // (origin.xyz, t)
	__global float4* soa_ray_dir_time,     // (dir.xyz, time)
	__global float4* soa_rlh_acc,          // accumulation buffer (rgba)
	__global float4* soa_rlh_mask_pdf,     // (throughput mask.xyz, last_bsdf_pdf)
	__global uint4*  soa_bounce,           // (diff|(spec<<16), trans|(scatters<<16), total, samples)
	__global uint*   soa_flags,            // bit0=wasSpecular  bit1=reset

	__constant new_bvhNode* new_bvh_node,

	/* runtime render parameters */
	__constant RenderParams* params,

	/* firefly clamping threshold (0 = disabled) */
	const float clamp_threshold,

	/* env-map importance sampling tables (all NULL / size 0 when disabled) */
	__global const float* env_marginal_cdf,   // H floats
	__global const float* env_conditional_cdf, // W*H floats
	__global const float* env_pdf,             // W*H floats
	const int env_map_width,
	const int env_map_height,

	/* per-material texture array (normal maps & roughness maps) */
	__read_only image2d_array_t mat_textures
) {
	const int work_item_id = get_global_id(0);			/* the unique global id of the work item for the current pixel */

	// The host pads global size to a multiple of local size, so guard tail threads.
	if (work_item_id >= width * height)
		return;

	/* xy-coordinate of the pixel */
	const int2 i_coord = (int2)(work_item_id % width, work_item_id / width);

#if RNG_TYPE == 0
	// Hash pixel index and frame into well-distributed seeds.
	// Avoids the entropy loss of "% 1000" in the old formulation.
	uint _seed_base = (uint)i_coord.x + (uint)width * (uint)i_coord.y;
	_seed_base ^= _seed_base << 13u;
	_seed_base ^= _seed_base >> 17u;
	_seed_base ^= _seed_base << 5u;
	uint seed0 = _seed_base * 1664525u + 1013904223u;
	seed0 ^= framenumber * 2246822519u;
	seed0 ^= (uint)random0 * 2246822519u;
	uint seed1 = seed0 * 1664525u + 1013904223u;
	seed1 ^= (uint)random1 * 2246822519u;
	// Warm-up the MWC generator to discard initial correlation
	seed0 = 36969u * (seed0 & 65535u) + (seed0 >> 16u);
	seed1 = 18000u * (seed1 & 65535u) + (seed1 >> 16u);
#elif RNG_TYPE == 1
	ulong state = (ulong)((uint)i_coord.x + (uint)width * (uint)i_coord.y + 1u) * 6364136223846793005UL
	              ^ ((ulong)framenumber * 1442695040888963407UL)
	              ^ (ulong)(uint)random0;
#elif RNG_TYPE == 2
	const float2 f_coord = (float2)((float)(i_coord.x) / width, (float)(i_coord.y) / height);
	double seed = dot(f_coord, (float2)(framenumber % 1000 + random0 * 100, framenumber % 333 + random1 * 33));
#endif

	const float4 _ray_org_t  = soa_ray_org_t[work_item_id];
	const float4 _ray_dir_tm = soa_ray_dir_time[work_item_id];
	Ray ray;
	ray.origin   = _ray_org_t.xyz;
	ray.dist     = _ray_org_t.w;
	ray.dir      = _ray_dir_tm.xyz;
	ray.time     = _ray_dir_tm.w;
	ray.normal   = (float3)(0.0f);
	ray.pos      = (float3)(0.0f);
	ray.uv       = (float2)(0.0f);
	ray.tangent  = (float3)(0.0f);
	ray.backside = false;

	RLH rlh_val;
	{
		rlh_val.acc            = soa_rlh_acc[work_item_id];
		const float4 _mp       = soa_rlh_mask_pdf[work_item_id];
		rlh_val.mask           = _mp.xyz;
		rlh_val.last_bsdf_pdf  = _mp.w;
		const uint4 _bn        = soa_bounce[work_item_id];
		rlh_val.bounce.diff     = (ushort)(_bn.s0 & 0xFFFFu);
		rlh_val.bounce.spec     = (ushort)(_bn.s0 >> 16u);
		rlh_val.bounce.trans    = (ushort)(_bn.s1 & 0xFFFFu);
		rlh_val.bounce.scatters = (ushort)(_bn.s1 >> 16u);
		rlh_val.bounce.total    = _bn.s2;
		rlh_val.samples         = _bn.s3;
		const uint _fg         = soa_flags[work_item_id];
		rlh_val.bounce.wasSpecular = (_fg & 1u) != 0u;
		rlh_val.reset              = (_fg & 2u) != 0u;
	}
	RLH* rlh = &rlh_val;

	const Scene scene = { mesh_mats, mesh_pos, mesh_joker, mesh_type, primitive_indices, new_bvh_node, (const uint* )&mesh_count, vertices, normals };

	const EnvMapIS envIS = { env_marginal_cdf, env_conditional_cdf, env_pdf, env_map_width, env_map_height };

#if defined(VIEW_OPTION)
#if VIEW_OPTION == VIEW_RESULTS
	for (int _bounce = 0; _bounce < BOUNCES_PER_FRAME; ++_bounce) {
		if (rlh->reset || rlh->samples == 0) {
			++rlh->samples;
			rlh->bounce.total    = 0;
			rlh->bounce.diff     = 0;
			rlh->bounce.spec     = 0;
			rlh->bounce.trans    = 0;
			rlh->bounce.scatters = 0;
			rlh->bounce.wasSpecular = true;
			rlh->reset           = false;
			rlh->last_bsdf_pdf   = 1.0f;
			rlh->mask            = (float3)(1.0f);
			ray = createCamRay(i_coord, width, height, cam, RNG_SEED_VALUE_P);
		}

		float4 sample = radiance(&scene, env_map, &envIS, mat_textures, &ray, rlh, params, RNG_SEED_VALUE_P);
		if (clamp_threshold > 0.0f) {
			float lum = 0.2126f * sample.x + 0.7152f * sample.y + 0.0722f * sample.z;
			if (lum > clamp_threshold)
				sample.xyz *= clamp_threshold / lum;
		}
		rlh->acc += sample;
	}
#elif VIEW_OPTION == VIEW_NORMAL
	radiance(&scene, env_map, &envIS, mat_textures, &ray, rlh, params, RNG_SEED_VALUE_P);
	rlh->acc = (float4)(ray.normal, 1.0f);
#elif VIEW_OPTION == VIEW_STACK_INDEX
	radiance(&scene, env_map, &envIS, mat_textures, &ray, rlh, params, RNG_SEED_VALUE_P);
	// rlh->acc = (float4)((float3)((float)(64-ray.bvh_stackIndex)/64.0f), 1.0f);
	rlh->acc = (float4)((float3)(fmin(1.0f, (float)(ray.bvh_stackIndex))), 1.0f);
#elif VIEW_OPTION == VIEW_BVH_HIT
	radiance(&scene, env_map, &envIS, mat_textures, &ray, rlh, params, RNG_SEED_VALUE_P);
	rlh->acc = (float4)(ray.normal, 1.0f);
#endif
#else
	rlh->acc = (float4)(1.0f, 0.0f, 1.0f, 1.0f);
#endif

	soa_ray_org_t[work_item_id]    = (float4)(ray.origin, ray.dist);
	soa_ray_dir_time[work_item_id] = (float4)(ray.dir,    ray.time);
	soa_rlh_acc[work_item_id]      = rlh->acc;
	soa_rlh_mask_pdf[work_item_id] = (float4)(rlh->mask,  rlh->last_bsdf_pdf);
	soa_bounce[work_item_id] = (uint4)(
		(uint)rlh->bounce.diff  | ((uint)rlh->bounce.spec  << 16u),
		(uint)rlh->bounce.trans | ((uint)rlh->bounce.scatters << 16u),
		rlh->bounce.total,
		rlh->samples);
	soa_flags[work_item_id] = (rlh->bounce.wasSpecular ? 1u : 0u)
	                        | (rlh->reset               ? 2u : 0u);

	/* update the output GLTexture */
#if VIEW_OPTION == VIEW_RESULTS
	write_imagef(output_tex, i_coord, rlh->acc / (float)(rlh->samples));
#else
	write_imagef(output_tex, i_coord, rlh->acc);
#endif

}

#endif
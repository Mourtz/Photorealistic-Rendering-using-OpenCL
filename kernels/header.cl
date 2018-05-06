#ifndef __HEADER__
#define __HEADER__

/* Epsilons */
#define EPS2	1e-2f
#define EPS3	1e-3f
#define EPS4	1e-4f
#define EPS5	1e-5f
#define EPS		EPS5
/* Infinity */
#define INF		2e1f

#define PI				 3.1415926535897932384626433832795f
#define PI_HALF			 1.5707963267948966192313216916398f
#define TWO_PI			 6.283185307179586476925286766559f
#define FOUR_PI			 12.566370614359172953850573533118f
#define INV_PI			 0.3183098861837906715377675267450f
#define INV_TWO_PI		 0.1591549430918953357688837633725f
#define INV_FOUR_PI		 0.0795774715459476678844418816863f
#define SQRT_PI			 1.7724538509055160272981674833411f
#define ONE_OVER_SQRT_PI 0.5641895835477562869480794515608f

#define F3_EPS			 (float3)(EPS)
#define F3_ZERO			 (float3)(0.0f)
#define F3_ONE			 (float3)(1.0f)

#define F3_UP			 (float3)(0.0f, 1.0f, 0.0f)
#define F3_DOWN			 (float3)(0.0f, -1.0f, 0.0f)
#define F3_RIGHT		 (float3)(1.0f, 0.0f, 0.0f)
#define F3_LEFT			 (float3)(-1.0f, 0.0f, 0.0f)
#define F3_FRONT		 (float3)(0.0f, 0.0f, 1.0f)
#define F3_BACK			 (float3)(0.0f, 0.0f, -1.0f)

#define RAD				 0.01745329251994329576923690768489f
#define E				 2.71828182845904523536028747135266f

#define BIT(N)			 ( 0b1<<N )
#define HALF_BYTE(N)	 ( 0xF<<(N*4) )
#define BYTE(N)			 ( 0xFF<<(N*8) )
#define FIRST_16		 ( 0xFFFF )
#define LAST_16			 ( 0xFFFF0000 )

//#define DEBUG

/* Volumetric Pathtracing */
#GLOBAL_MEDIUM#
#ifdef GLOBAL_MEDIUM
//#define VOLUME_CAUSTICS

#define GLOBAL_FOG_DENSITY		#GLOBAL_FOG_DENSITY#
#define GLOBAL_FOG_SIGMA_A		#GLOBAL_FOG_SIGMA_A#
#define GLOBAL_FOG_SIGMA_S		#GLOBAL_FOG_SIGMA_S#
#define GLOBAL_FOG_SIGMA_T		#GLOBAL_FOG_SIGMA_T#
#define GLOBAL_FOG_ABS_ONLY		#GLOBAL_FOG_ABS_ONLY#
#endif

/* total light sources */
#define LIGHT_COUNT				#LIGHT_COUNT#
#define INV_LIGHT_COUNT			#INV_LIGHT_COUNT#
/* light indices */
__constant uint LIGHT_INDICES[LIGHT_COUNT] = { #LIGHT_INDICES# };
/* max light bounces */
#define LIGHT_BOUNCES			2

/* Seperate bounce controls for eye tracing */
#define MAX_BOUNCES				#MAX_BOUNCES#
#define MAX_DIFF_BOUNCES		#MAX_DIFF_BOUNCES#
#define MAX_SPEC_BOUNCES		#MAX_SPEC_BOUNCES#
#define MAX_TRANS_BOUNCES		#MAX_TRANS_BOUNCES#
#define MAX_SCATTERING_EVENTS	#MAX_SCATTERING_EVENTS#

/* Raymarching Stuff */
#define MARCHING_STEPS			#MARCHING_STEPS#
#define SHADOW_MARCHING_STEPS	#SHADOW_MARCHING_STEPS#

/* Mesh types */
#define SPHERE	#SPHERE#
#define BOX		#BOX#
#define SDF		#SDF#
#define QUAD	#QUAD#

/* SDF primitives */
#define SDF_SPHERE		#SDF_SPHERE#
#define SDF_BOX			#SDF_BOX#
#define SDF_ROUND_BOX	#SDF_ROUND_BOX#
#define SDF_PLANE		#SDF_PLANE#

/* Material Types */
#define LIGHT		#LIGHT#
#define DIFF		#DIFF#
#define GLOSSY		#SPEC#
#define REFR		#REFR#
#define COAT		#COAT#
#define VOL			#VOL#
#define TRANS		#TRANS#
#define SPECSUB		#SPECSUB#
#define ABS_REFR	#ABS_REFR#
#define ABS_REFR2	#ABS_REFR2#

typedef struct {
	float3 origin;			// origin
	float3 dir;				// direction
	float3 incomingRayDir;	// incoming ray direction
	float3 normal;			// normal
	float2 uv;				// uv
	float3 pos;				// position
	float t;				// dist from origin
	bool backside;			// inside?
	int hitFace;			// hitface id
} Ray;

//------------- MATERIAL -------------

typedef struct {
	float3 color;		// albedo/specular
	float roughness;	// surface roughness
	int t;				// mesh type
	int tex;			// asigned texture/s
	bool b;				// backface culling
} Material;

//------------- BVH -------------

typedef struct {
	float4 bbMin;
	float4 bbMax;
} bvhNode;

typedef struct {
	float4 pos;
	float4 rgb;
	float4 data;
} light_t;

typedef struct {
	uint NUM_NODES;
	__global const bvhNode* bvh;
	__global const uint4* facesV;
	__global const uint4* facesN;
	__global const float4* vertices;
	__global const float4* normals;
	__constant Material* mat;
} Scene;

//------------- MESH -------------

typedef struct {
	Material mat;	// assigned material
	float3 pos;		// position
	float16 joker;	// generic data
	int t;			// type
} Mesh;

#endif

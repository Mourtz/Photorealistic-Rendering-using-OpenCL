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

#ALPHA_TESTING#

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
#define COND		#COND#
#define ROUGH_COND	#ROUGH_COND#
#define DIEL		#DIEL#
#define ROUGH_DIEL	#ROUGH_DIEL#
#define COAT		#COAT#
#define VOL			#VOL#
#define TRANS		#TRANS#
#define SPECSUB		#SPECSUB#

#define ABS_REFR	#ABS_REFR#
#define ABS_REFR2	#ABS_REFR2#

/* Lobes */
#define NullLobe                  0
#define GlossyReflectionLobe      (1 << 0)
#define GlossyTransmissionLobe    (1 << 1)
#define DiffuseReflectionLobe     (1 << 2)
#define DiffuseTransmissionLobe   (1 << 3)
#define SpecularReflectionLobe    (1 << 4)
#define SpecularTransmissionLobe  (1 << 5)
#define AnisotropicLobe           (1 << 6)
#define ForwardLobe               (1 << 7)

#define GlossyLobe                (  GlossyReflectionLobe |   GlossyTransmissionLobe)
#define DiffuseLobe               ( DiffuseReflectionLobe |  DiffuseTransmissionLobe)
#define SpecularLobe              (SpecularReflectionLobe | SpecularTransmissionLobe)

#define TransmissiveLobe          (GlossyTransmissionLobe | DiffuseTransmissionLobe | SpecularTransmissionLobe)
#define ReflectiveLobe            (GlossyReflectionLobe   | DiffuseReflectionLobe   | SpecularReflectionLobe)

#define AllLobes                  (TransmissiveLobe | ReflectiveLobe | AnisotropicLobe)
#define AllButSpecular            (~(SpecularLobe | ForwardLobe))

/* Light Sources */
#ifdef LIGHT

/* total light sources */
#define LIGHT_COUNT				#LIGHT_COUNT#
#define INV_LIGHT_COUNT			#INV_LIGHT_COUNT#
/* light indices */
__constant uint LIGHT_INDICES[LIGHT_COUNT] = { #LIGHT_INDICES# };
/* max light bounces */
#define LIGHT_BOUNCES			2
#endif

//------------- Tangent Frame -------------

typedef struct {
	float3 normal, tangent, bitangent;
} TangentFrame;

// [Duff et al. 17] Building An Orthonormal Basis, Revisited. JCGT. 2017.
TangentFrame createTangentFrame(const float3* normal) {
	TangentFrame res;

	float sn = copysign(1.0f, normal->z);
	float a = -1.0f / (sn + normal->z);
	float b = normal->x * normal->y * a;

	res.normal = *normal;
	res.tangent = (float3)(1.0f + sn * normal->x * normal->x * a, sn * b, -sn * normal->x);
	res.bitangent = (float3)(b, sn + normal->y * normal->y * a, -normal->y);
	return res;
}

float3 toLocal(const TangentFrame* tf, const float3 p) {
	return (float3)(
		dot(tf->tangent, p),
		dot(tf->bitangent, p),
		dot(tf->normal, p)
		);
}

float3 toGlobal(const TangentFrame* tf, const float3 p) {
	return tf->tangent * p.x +
		tf->bitangent * p.y +
		tf->normal * p.z;
}

//------------- Surface Scatter Event -------------

typedef struct { 
	float3 wi, wo;
	float3 weight;
	float pdf;
	uchar requestedLobe;
	uchar sampledLobe;
	TangentFrame frame;
} SurfaceScatterEvent;

//------------- Material -------------

typedef struct {
	union {
		float3 color;
		float3 emission;
		float3 albedo;
	};
	float3 ior;
	float3 eta;
	float3 k;
	float roughness;	// surface roughness
	ushort t;			// mesh type
	uchar lobes;		// asigned lobe/s
	uchar dist;			// distribution
} Material;

//------------- MESH -------------

typedef struct {
	Material mat;	// assigned material
	float3 pos;		// position
	union {			// generic data
		float16 joker;	
		float* value;
		float radius;
	};
	uchar t;		// type
} Mesh;

//------------- Ray -------------

typedef struct {
	float3 origin;			// origin
	float3 dir;				// direction
	float3 normal;			// normal
	float3 pos;				// position
	float t;				// dist from origin
	bool backside;			// inside?
	// int hitFace;			// hitface id
} Ray;

//------------- BVH -------------

typedef struct {
	float4 bbMin;
	float4 bbMax;
} bvhNode;

//------------- Light Sampler -------------
typedef struct {
	float3 d;
	float dist;
	float pdf;
	//const Medium* medium;
} LightSample;

#if 0
typedef struct {
	float4 pos;
	float4 rgb;
	float4 data;
} light_t;
#endif

typedef struct {
	__constant Mesh* meshes;
	const uint* mesh_count;
	const uint NUM_NODES;
	__constant bvhNode* bvh;
	__constant uint4* facesV;
	__constant uint4* facesN;
	__constant float4* vertices;
	__constant float4* normals;
	__constant Material* mat;
} Scene;

#endif

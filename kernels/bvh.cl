typedef struct { 
	char* oName;
	uint* facesV;
    uint* facesVN;
} object3D;

typedef struct {
	object3D* mObjects;
	int* mFacesMtl;
	uint* mFacesV;
	uint* mFacesVN;
	uint* mFacesVT;
	float* mNormals;
	float* mTextures;
	float* mVertices;
} ObjParser;

typedef struct {
    ObjParser* mObjParser;
} ModelLoader;

typedef struct {
	uint4 face;
	uint4 normals;
	float3 bbMin;
	float3 bbMax;
} Tri;

typedef struct BVHNode {
	struct BVHNode* lc;
	struct BVHNode* rc;
	struct BVHNode* p;
	Tri faces;
	float3 bbMin;
	float3 bbMax;
	uint id;
	uint depth;
	uint numSkipsToHere;
	bool skipNextLeft;
} BVHNode;

typedef struct {
	BVHNode* mContainerNodes;
	BVHNode* mLeafNodes;
	BVHNode* mNodes;
	BVHNode* mRoot;
	uint mMaxFaces;
	uint mDepthReached;
} BVH;

typedef struct { float4 bbMin, bbMax; } bvhNode_cl;

//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
//=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

//---------------------- ModelLoader----------------------

__kernel void getFacesOfObject(
	__global const uint* facesV,
	__global uint4* faces, 
	int offset
) {
	const uint work_item_id = get_global_id(0);

	faces[work_item_id] = (uint4)(
		facesV[work_item_id*3 + 0],
		facesV[work_item_id*3 + 1],
		facesV[work_item_id*3 + 2],
		offset + work_item_id
	);

}

//---------------------- BVH ----------------------

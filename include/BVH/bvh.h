#pragma once

#include <Model/model_loader.h>
#include <Math/linear_algebra.h>
#include <Math/MathHelp.h>

struct BVHNode {
	BVHNode* leftChild;
	BVHNode* rightChild;
	BVHNode* parent;
	vector<Tri> faces;
	vec3 bbMin;
	vec3 bbMax;
	cl_uint id;
	cl_uint depth;
	cl_uint numSkipsToHere;
	bool skipNextLeft;
};

struct bvhNode_cl {
	cl_float4 bbMin;
	cl_float4 bbMax;
};

class BVH {

public:
	BVH();
	BVH(
		const vector<object3D> sceneObjects,
		const vector<cl_float> vertices,
		const vector<cl_float> normals
	);
	~BVH();
	vector<BVHNode*> getContainerNodes();
	cl_uint getDepth();
	vector<BVHNode*> getLeafNodes();
	vector<BVHNode*> getNodes();
	BVHNode* getRoot();
	void visualize(vector<cl_float>* vertices, vector<cl_uint>* indices);

protected:
	void assignFacesToBins(
		const cl_uint axis, const cl_uint splits, const vector<Tri>* faces,
		const vector< vector<vec3> >* leftBin,
		const vector< vector<vec3> >* rightBin,
		vector< vector<Tri> >* leftBinFaces, vector< vector<Tri> >* rightBinFaces
	);
	BVHNode* buildTree(
		const vector<Tri> faces, const vec3 bbMin, const vec3 bbMax,
		cl_uint depth, const cl_float rootSA
	);
	vector<BVHNode*> buildTreesFromObjects(
		const vector<object3D>* sceneObjects,
		const vector<cl_float>* vertices,
		const vector<cl_float>* normals
	);
	void buildWithMeanSplit(
		BVHNode* node, const vector<Tri> faces,
		vector<Tri>* leftFaces, vector<Tri>* rightFaces
	);
	cl_float buildWithSAH(
		BVHNode* node, vector<Tri> faces,
		vector<Tri>* leftFaces, vector<Tri>* rightFaces
	);
	cl_float calcSAH(
		const cl_float leftSA, const cl_float leftNumFaces,
		const cl_float rightSA, const cl_float rightNumFaces
	);
	void combineNodes(const cl_uint numSubTrees);
	vector<Tri> facesToTriStructs(
		const vector<cl_uint4>* facesThisObj, const vector<cl_uint4>* faceNormalsThisObj,
		const vector<cl_float4>* vertices4, const vector<float>* normals
	);
	cl_float getMean(const vector<Tri> faces, const cl_uint axis);
	cl_float getMeanOfNodes(const vector<BVHNode*> nodes, const cl_uint axis);
	void groupTreesToNodes(vector<BVHNode*> nodes, BVHNode* parent, cl_uint depth);
	void growAABBsForSAH(
		const vector<Tri>* faces,
		vector< vector<vec3> >* leftBB, vector< vector<vec3> >* rightBB,
		vector<cl_float>* leftSA, vector<cl_float>* rightSA
	);
	//void logStats(boost::posix_time::ptime timerStart);
	cl_uint longestAxis(const BVHNode* node);
	BVHNode* makeNode(const vector<Tri> faces, bool ignore);
	BVHNode* makeContainerNode(const vector<BVHNode*> subTrees, const bool isRoot);
	void orderNodesByTraversal();
	vector<cl_float4> packFloatAsFloat4(const vector<cl_float>* vertices);
	cl_uint setMaxFaces(const int value);
	void skipAheadOfNodes();
	void splitBySAH(
		cl_float* bestSAH, const cl_uint axis, vector<Tri> faces,
		vector<Tri>* leftFaces, vector<Tri>* rightFaces
	);
	cl_float splitFaces(
		const vector<Tri> faces, const cl_float midpoint, const cl_uint axis,
		vector<Tri>* leftFaces, vector<Tri>* rightFaces
	);
	void splitNodes(
		const vector<BVHNode*> nodes, const cl_float midpoint, const cl_uint axis,
		vector<BVHNode*>* leftGroup, vector<BVHNode*>* rightGroup
	);
	void visualizeNextNode(
		const BVHNode* node, vector<cl_float>* vertices, vector<cl_uint>* indices
	);

	vector<BVHNode*> mContainerNodes;
	vector<BVHNode*> mLeafNodes;
	vector<BVHNode*> mNodes;
	BVHNode* mRoot;

	cl_uint mMaxFaces;
	cl_uint mDepthReached;

};

#pragma once

#include <Model/model_loader.h>
#include <Math/linear_algebra.h>
#include <Math/MathHelp.h>

struct BVHNode {
	BVHNode* leftChild;
	BVHNode* rightChild;
	BVHNode* parent;
	std::vector<Tri> faces;
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
	BVH(const std::unique_ptr<IO::SceneData>& sceneData);
	~BVH();
	const std::vector<BVHNode*> getContainerNodes() const;
	cl_uint getDepth() const;
	const std::vector<BVHNode*> getLeafNodes() const;
	const std::vector<BVHNode*> getNodes() const;
	const BVHNode* getRoot() const;
	void visualize(std::vector<cl_float>* vertices, std::vector<cl_uint>* indices);

protected:
	std::vector<BVHNode*> buildTreesFromObjects(const std::unique_ptr<IO::SceneData>& sceneData);

	BVHNode* buildTree(
		const std::vector<Tri> faces, const vec3 bbMin, const vec3 bbMax,
		cl_uint depth, const cl_float rootSA
	);
	void buildWithMeanSplit(
		BVHNode* node, const std::vector<Tri> faces,
		std::vector<Tri>* leftFaces, std::vector<Tri>* rightFaces
	);
	cl_float buildWithSAH(
		BVHNode* node, std::vector<Tri> faces,
		std::vector<Tri>* leftFaces, std::vector<Tri>* rightFaces
	);
	cl_float calcSAH(
		const cl_float leftSA, const cl_float leftNumFaces,
		const cl_float rightSA, const cl_float rightNumFaces
	);
	void combineNodes(const cl_uint numSubTrees);
	cl_float getMean(const std::vector<Tri> faces, const cl_uint axis);
	cl_float getMeanOfNodes(const std::vector<BVHNode*> nodes, const cl_uint axis);
	void groupTreesToNodes(std::vector<BVHNode*> nodes, BVHNode* parent, cl_uint depth);
	void growAABBsForSAH(
		const std::vector<Tri>* faces,
		std::vector< std::vector<vec3> >* leftBB, std::vector< std::vector<vec3> >* rightBB,
		std::vector<cl_float>* leftSA, std::vector<cl_float>* rightSA
	);
	//void logStats(boost::posix_time::ptime timerStart);
	cl_uint longestAxis(const BVHNode* node);
	BVHNode* makeNode(const std::vector<Tri> faces, bool ignore);
	BVHNode* makeContainerNode(const std::vector<BVHNode*> subTrees, const bool isRoot);
	void orderNodesByTraversal();
	std::vector<cl_float4> packFloatAsFloat4(const std::vector<cl_float>* vertices);
	cl_uint setMaxFaces(const int value);
	void skipAheadOfNodes();
	void splitBySAH(
		cl_float* bestSAH, const cl_uint axis, std::vector<Tri> faces,
		std::vector<Tri>* leftFaces, std::vector<Tri>* rightFaces
	);
	cl_float splitFaces(
		const std::vector<Tri> faces, const cl_float midpoint, const cl_uint axis,
		std::vector<Tri>* leftFaces, std::vector<Tri>* rightFaces
	);
	void splitNodes(
		const std::vector<BVHNode*> nodes, const cl_float midpoint, const cl_uint axis,
		std::vector<BVHNode*>* leftGroup, std::vector<BVHNode*>* rightGroup
	);
	void visualizeNextNode(
		const BVHNode* node, std::vector<cl_float>* vertices, std::vector<cl_uint>* indices
	);
private:
	std::vector<BVHNode*> mContainerNodes;
	std::vector<BVHNode*> mLeafNodes;
	std::vector<BVHNode*> mNodes;
	BVHNode* mRoot;

	cl_uint mMaxFaces;
	cl_uint mDepthReached;

};

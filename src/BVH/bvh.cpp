#include <BVH/bvh.h>

#include <iostream>
#include <vector>
#include <algorithm>

using std::vector;
using std::cout;

struct sortFacesCmp {
	cl_uint axis;

	sortFacesCmp(const cl_uint axis) {
		this->axis = axis;
	};

	bool operator()(const Tri a, const Tri b) {
		cl_float cenA = (a.bbMin[this->axis] + a.bbMax[this->axis]) * 0.5f;
		cl_float cenB = (b.bbMin[this->axis] + b.bbMax[this->axis]) * 0.5f;

		return cenA < cenB;
	};
};

constexpr cl_int BVH_MAXFACES(1);
constexpr cl_int BVH_SAHFACESLIMIT(100000);
constexpr bool BVH_SKIPAHEAD(true);
constexpr cl_float BVH_SKIPAHEAD_CMP(0.7);

/*-------------------------------------------------------------------------------------------------*/

BVH::BVH() {}

BVH::BVH(const std::unique_ptr<IO::SceneData>& sceneData){
	mDepthReached = 0;
	this->setMaxFaces(BVH_MAXFACES);

	vector<BVHNode*> subTrees = this->buildTreesFromObjects(sceneData);
	mRoot = this->makeContainerNode(subTrees, true);
	this->groupTreesToNodes(subTrees, mRoot, 1);
	this->combineNodes(subTrees.size());
}

BVH::~BVH() {
	for (cl_uint i = 0; i < mNodes.size(); i++) {
		delete mNodes[i];
	}
}

void BVH::assignFacesToBins(
	const cl_uint axis, const cl_uint splits, const vector<Tri>* faces,
	const vector< vector<vec3> >* leftBin,
	const vector< vector<vec3> >* rightBin,
	vector< vector<Tri> >* leftBinFaces, vector< vector<Tri> >* rightBinFaces
) {
	for (cl_uint i = 0; i < splits; i++) {
		vector<vec3> leftAABB = (*leftBin)[i];
		vector<vec3> rightAABB = (*rightBin)[i];

		for (cl_uint j = 0; j < faces->size(); j++) {
			Tri tri = (*faces)[j];

			if (tri.bbMin[axis] <= leftAABB[1][axis] && tri.bbMax[axis] >= leftAABB[0][axis]) {
				Tri triCpy;
				triCpy.face = tri.face;
				triCpy.bbMin = vec3(tri.bbMin);
				triCpy.bbMax = vec3(tri.bbMax);
				triCpy.bbMin[axis] = fmax(tri.bbMin[axis], leftAABB[0][axis]);
				triCpy.bbMax[axis] = fmin(tri.bbMax[axis], leftAABB[1][axis]);

				(*leftBinFaces)[i].push_back(triCpy);
			}
			if (tri.bbMin[axis] <= rightAABB[1][axis] && tri.bbMax[axis] >= rightAABB[0][axis]) {
				Tri triCpy;
				triCpy.face = tri.face;
				triCpy.bbMin = vec3(tri.bbMin);
				triCpy.bbMax = vec3(tri.bbMax);
				triCpy.bbMin[axis] = fmax(tri.bbMin[axis], rightAABB[0][axis]);
				triCpy.bbMax[axis] = fmin(tri.bbMax[axis], rightAABB[1][axis]);

				(*rightBinFaces)[i].push_back(triCpy);
			}
		}
	}
}

BVHNode* BVH::buildTree(
	const vector<Tri> faces, const vec3 bbMin, const vec3 bbMax,
	cl_uint depth, const cl_float rootSA
) {
	BVHNode* containerNode = this->makeNode(faces, false);

	containerNode->depth = depth;
	mDepthReached = (depth > mDepthReached) ? depth : mDepthReached;

	// leaf node
	if (faces.size() <= mMaxFaces) {
		if (faces.size() <= 0) {
			cout << "[BVH] No faces in node." << std::endl;
		}

		containerNode->faces = faces;

		return containerNode;
	}

	vector<Tri> leftFaces, rightFaces;
	vec3 bbMinLeft, bbMaxLeft, bbMinRight, bbMaxRight;

	// SAH takes some time. Don't do it if there are too many faces.
	if (faces.size() <= BVH_SAHFACESLIMIT) {
		this->buildWithSAH(
			containerNode, faces, &leftFaces, &rightFaces
		);
	}
	// Faster to build: Splitting at the midpoint of the longest axis.
	else {
		char msg[256];
		snprintf(msg, 256, "[BVH] Too many faces in node for SAH. Splitting by mean position. (%lu faces)", faces.size());
		cout << msg << std::endl;

		this->buildWithMeanSplit(containerNode, faces, &leftFaces, &rightFaces);
	}

	if (
		leftFaces.size() == 0 ||
		rightFaces.size() == 0
		) {
		if (faces.size() > mMaxFaces) {
			cout << "[BVH] More faces than can be traversed in node." << std::endl;
		}

		containerNode->faces = faces;

		return containerNode;
	}

	containerNode->leftChild = this->buildTree(
		leftFaces, bbMinLeft, bbMaxLeft, depth + 1, rootSA
	);
	containerNode->rightChild = this->buildTree(
		rightFaces, bbMinRight, bbMaxRight, depth + 1, rootSA
	);

	return containerNode;
}

std::vector<BVHNode*> BVH::buildTreesFromObjects(const std::unique_ptr<IO::SceneData>& sceneData){
	using namespace IO;
	constexpr cl_float RENDER_PHONGTESS = 0;
	vector<BVHNode*> subTrees;
	cl_uint offset = 0;

	for(const auto& mesh : *sceneData){
		const std::vector<unsigned int>& faces = getIndices(mesh);
		const std::vector<float>& vertices = getPositions(mesh);
		const std::vector<float>& normals = getNormals(mesh);
		
		vector<cl_uint4> facesThisObj;
		// ModelLoader::getFacesOfObject((*sceneObjects)[i], facesThisObj, offset);
		for(int i = 0; i < faces.size();i+=3){
			facesThisObj.push_back({faces[i+0], faces[i+1], faces[i+2], static_cast<unsigned>(offset + facesThisObj.size())});
		}
		offset += facesThisObj.size();
		
		
		//------------------------------------------------------------------------
		
		vector<Tri> tris;
		
		for (cl_uint j = 0; j < facesThisObj.size(); j++) {
			Tri tri;

			tri.face = facesThisObj[j];
			tri.normals = facesThisObj[j];

			vector<vec3> v;
			v.push_back(vec3(vertices[tri.face.x*3+0], vertices[tri.face.x*3+1], vertices[tri.face.x*3+2]));
			v.push_back(vec3(vertices[tri.face.y*3+0], vertices[tri.face.y*3+1], vertices[tri.face.y*3+2]));
			v.push_back(vec3(vertices[tri.face.z*3+0], vertices[tri.face.z*3+1], vertices[tri.face.z*3+2]));

			vec3 bbMin, bbMax;
			MathHelp::getAABB(v, bbMin, bbMax);
			tri.bbMin = bbMin;
			tri.bbMax = bbMax;

			tris.emplace_back(tri);
		}
		
		BVHNode* rootNode = this->makeNode(tris, true);
		cl_float rootSA = MathHelp::getSurfaceArea(rootNode->bbMin, rootNode->bbMax);

		vec3 bbMin, bbMax;
		BVHNode* st = this->buildTree(tris, bbMin, bbMax, 1, rootSA);
		subTrees.push_back(st);
	}

	return subTrees;
}

void BVH::buildWithMeanSplit(
	BVHNode* node, const vector<Tri> faces,
	vector<Tri>* leftFaces, vector<Tri>* rightFaces
) {
	cl_float bestSAH = FLT_MAX;

	for (cl_uint axis = 0; axis <= 2; axis++) {
		vector<Tri> leftFacesTmp, rightFacesTmp;
		cl_float splitPos = this->getMean(faces, axis);
		cl_float sah = this->splitFaces(faces, splitPos, axis, &leftFacesTmp, &rightFacesTmp);

		if (sah < bestSAH) {
			bestSAH = sah;
			*leftFaces = leftFacesTmp;
			*rightFaces = rightFacesTmp;
		}
	}
}

cl_float BVH::buildWithSAH(
	BVHNode* node, vector<Tri> faces,
	vector<Tri>* leftFaces, vector<Tri>* rightFaces
) {
	cl_float bestSAH = FLT_MAX;

	for (cl_uint axis = 0; axis <= 2; axis++) {
		this->splitBySAH(&bestSAH, axis, faces, leftFaces, rightFaces);
	}

	return bestSAH;
}


cl_float BVH::calcSAH(
	const cl_float leftSA, const cl_float leftNumFaces,
	const cl_float rightSA, const cl_float rightNumFaces
) {
	return (leftSA * leftNumFaces + rightSA * rightNumFaces);
}

void BVH::combineNodes(const cl_uint numSubTrees) {
	if (numSubTrees > 1) {
		mNodes.push_back(mRoot);
	}

	mNodes.insert(mNodes.end(), mContainerNodes.begin(), mContainerNodes.end());

	for (cl_uint i = 0; i < mNodes.size(); i++) {
		// Leaf node
		if (mNodes[i]->faces.size() > 0) {
			mLeafNodes.push_back(mNodes[i]);
		}
		// Not a leaf node
		else {
			mNodes[i]->leftChild->parent = mNodes[i];
			mNodes[i]->rightChild->parent = mNodes[i];

			// Set the node with the bigger surface area as the left one
			cl_float leftSA = MathHelp::getSurfaceArea(mNodes[i]->leftChild->bbMin, mNodes[i]->leftChild->bbMax);
			cl_float rightSA = MathHelp::getSurfaceArea(mNodes[i]->rightChild->bbMin, mNodes[i]->rightChild->bbMax);

			if (rightSA > leftSA) {
				BVHNode* tmp = mNodes[i]->leftChild;
				mNodes[i]->leftChild = mNodes[i]->rightChild;
				mNodes[i]->rightChild = tmp;
			}
		}
	}

	this->orderNodesByTraversal();

	if (BVH_SKIPAHEAD) {
		this->skipAheadOfNodes();
	}
}

vector<Tri> BVH::facesToTriStructs(
	const vector<cl_uint4>* facesThisObj, const vector<cl_uint4>* faceNormalsThisObj,
	const vector<cl_float4>* vertices4, const vector<float>* normals
) {
	vector<cl_float4> normals4 = this->packFloatAsFloat4(normals);
	vector<Tri> triFaces;

	for (cl_uint j = 0; j < facesThisObj->size(); j++) {
		Tri tri;
		tri.face = (*facesThisObj)[j];
		tri.normals = (*faceNormalsThisObj)[j];
		MathHelp::triCalcAABB(&tri, vertices4, &normals4);
		triFaces.push_back(tri);
	}

	return triFaces;
}

cl_float BVH::getMean(const vector<Tri> faces, const cl_uint axis) {
	cl_float sum = 0.0f;

	for (cl_uint i = 0; i < faces.size(); i++) {
		Tri tri = faces[i];
		vec3 center = 0.5f * (tri.bbMin + tri.bbMax);
		sum += center[axis];
	}

	return sum / faces.size();
}

cl_float BVH::getMeanOfNodes(const vector<BVHNode*> nodes, const cl_uint axis) {
	cl_float sum = 0.0f;

	for (cl_uint i = 0; i < nodes.size(); i++) {
		vec3 center = (nodes[i]->bbMax - nodes[i]->bbMin) * 0.5f;
		sum += center[axis];
	}

	return sum / nodes.size();
}

void BVH::groupTreesToNodes(vector<BVHNode*> nodes, BVHNode* parent, cl_uint depth) {
	if (nodes.size() == 1) {
		return;
	}

	parent->depth = depth;
	mDepthReached = (depth > mDepthReached) ? depth : mDepthReached;

	cl_uint axis = this->longestAxis(parent);
	vector<BVHNode*> leftGroup, rightGroup;
	cl_float mean = this->getMeanOfNodes(nodes, axis);
	this->splitNodes(nodes, mean, axis, &leftGroup, &rightGroup);

	BVHNode* leftNode = this->makeContainerNode(leftGroup, false);
	parent->leftChild = leftNode;
	this->groupTreesToNodes(leftGroup, parent->leftChild, depth + 1);

	BVHNode* rightNode = this->makeContainerNode(rightGroup, false);
	parent->rightChild = rightNode;
	this->groupTreesToNodes(rightGroup, parent->rightChild, depth + 1);
}

void BVH::growAABBsForSAH(
	const vector<Tri>* faces,
	vector< vector<vec3> >* leftBB, vector< vector<vec3> >* rightBB,
	vector<cl_float>* leftSA, vector<cl_float>* rightSA
) {
	vec3 bbMin, bbMax;
	const cl_uint numFaces = faces->size();


	// Grow a bounding box face by face starting from the left.
	// Save the growing surface area for each step.

	for (cl_uint i = 0; i < numFaces - 1; i++) {
		Tri f = (*faces)[i];

		if (i == 0) {
			bbMin = (f.bbMin);
			bbMax = (f.bbMax);
		}
		else {
			bbMin = min3(bbMin, f.bbMin);
			bbMax = max3(bbMax, f.bbMax);
		}

		(*leftBB)[i] = vector<vec3>(2);
		(*leftBB)[i][0] = bbMin;
		(*leftBB)[i][1] = bbMax;
		(*leftSA)[i] = MathHelp::getSurfaceArea(bbMin, bbMax);
	}


	// Grow a bounding box face by face starting from the right.
	// Save the growing surface area for each step.

	for (int i = numFaces - 2; i >= 0; i--) {
		Tri f = (*faces)[i + 1];

		if (i == numFaces - 2) {
			bbMin = (f.bbMin);
			bbMax = (f.bbMax);
		}
		else {
			bbMin = min3(bbMin, f.bbMin);
			bbMax = max3(bbMax, f.bbMax);
		}

		(*rightBB)[i] = vector<vec3>(2);
		(*rightBB)[i][0] = bbMin;
		(*rightBB)[i][1] = bbMax;
		(*rightSA)[i] = MathHelp::getSurfaceArea(bbMin, bbMax);
	}
}

cl_uint BVH::longestAxis(const BVHNode* node) {
	vec3 sides = node->bbMax - node->bbMin;

	if (sides[0] > sides[1]) {
		return (sides[0] > sides[2]) ? 0 : 2;
	}
	else { // sides[1] > sides[0]
		return (sides[1] > sides[2]) ? 1 : 2;
	}
}

BVHNode* BVH::makeNode(const vector<Tri> tris, bool ignore) {
	BVHNode* node = new BVHNode();
	node->leftChild = NULL;
	node->rightChild = NULL;
	node->parent = NULL;
	node->depth = 0;
	node->skipNextLeft = false;
	node->numSkipsToHere = 0;

	vector<vec3> bbMins, bbMaxs;

	for (cl_uint i = 0; i < tris.size(); i++) {
		bbMins.push_back(tris[i].bbMin);
		bbMaxs.push_back(tris[i].bbMax);
	}

	vec3 bbMin;
	vec3 bbMax;
	MathHelp::getAABB(bbMins, bbMaxs, &bbMin, &bbMax);
	node->bbMin = bbMin;
	node->bbMax = bbMax;

	if (!ignore) {
		mContainerNodes.push_back(node);
	}

	return node;
}

BVHNode* BVH::makeContainerNode(const vector<BVHNode*> subTrees, const bool isRoot) {
	if (subTrees.size() == 1) {
		return subTrees[0];
	}

	BVHNode* node = new BVHNode();

	node->leftChild = NULL;
	node->rightChild = NULL;
	node->parent = NULL;
	node->depth = 0;
	node->skipNextLeft = false;
	node->numSkipsToHere = 0;
	node->bbMin = vec3(subTrees[0]->bbMin);
	node->bbMax = vec3(subTrees[0]->bbMax);

	for (cl_uint i = 1; i < subTrees.size(); i++) {
		node->bbMin = min3(node->bbMin, subTrees[i]->bbMin);
		node->bbMax = max3(node->bbMax, subTrees[i]->bbMax);
	}

	if (!isRoot) {
		mContainerNodes.push_back(node);
	}

	return node;
}

void BVH::orderNodesByTraversal() {
	vector<BVHNode*> nodesOrdered;
	BVHNode* node = mNodes[0];

	// Order the nodes.
	while (true) {
		nodesOrdered.push_back(node);

		if (node->leftChild != NULL) {
			node = node->leftChild;
		}
		else {
			// is left node, visit right sibling next
			if (node->parent->leftChild == node) {
				node = node->parent->rightChild;
			}
			// is right node, go up tree
			else if (node->parent->parent != NULL) {
				BVHNode* dummy = new BVHNode();
				dummy->parent = node->parent;

				// As long as we are on the right side of a (sub)tree,
				// skip parents until we either are at the root or
				// our parent has a true sibling again.
				while (dummy->parent->parent->rightChild == dummy->parent) {
					dummy->parent = dummy->parent->parent;

					if (dummy->parent->parent == NULL) {
						break;
					}
				}

				// Reached a parent with a true sibling.
				if (dummy->parent->parent != NULL) {
					node = dummy->parent->parent->rightChild;
				}
			}
		}

		if (nodesOrdered.size() >= mNodes.size()) {
			break;
		}
	}

	// Assign IDs.
	for (cl_uint i = 0; i < mNodes.size(); i++) {
		BVHNode* node = nodesOrdered[i];
		node->id = i;
		mNodes[i] = node;
	}
}

vector<cl_float4> BVH::packFloatAsFloat4(const vector<cl_float>* vertices) {
	vector<cl_float4> vertices4;

	for (cl_uint i = 0; i < vertices->size(); i += 3) {
		cl_float4 v = {
			(*vertices)[i + 0],
			(*vertices)[i + 1],
			(*vertices)[i + 2],
			0.0f
		};
		vertices4.push_back(v);
	}

	return vertices4;
}

cl_uint BVH::setMaxFaces(const int value) {
	mMaxFaces = fmax(value, 1);

	return mMaxFaces;
}

void BVH::skipAheadOfNodes() {
	cl_uint skippedLeft = 0;

	for (cl_uint i = 0; i < mNodes.size(); i++) {
		BVHNode* node = mNodes[i];
		node->numSkipsToHere = skippedLeft;

		// Left child exists and is not a leaf node.
		if (node->leftChild != NULL && node->leftChild->leftChild != NULL) {
			BVHNode* left = node->leftChild;

			cl_float saNode = MathHelp::getSurfaceArea(node->bbMin, node->bbMax);
			cl_float saLeft = MathHelp::getSurfaceArea(left->bbMin, left->bbMax);

			if (saLeft / saNode >= BVH_SKIPAHEAD_CMP) {
				node->skipNextLeft = true;
				skippedLeft++;
			}
		}
	}

	char msg[128];
	snprintf(msg, 128, "[BVH] Marked %u left child nodes as skippable.", skippedLeft);
	cout << msg << "\n";
}

void BVH::splitBySAH(
	cl_float* bestSAH, const cl_uint axis, vector<Tri> faces,
	vector<Tri>* leftFaces, vector<Tri>* rightFaces
) {
	std::sort(faces.begin(), faces.end(), sortFacesCmp(axis));
	const cl_uint numFaces = faces.size();

	vector<cl_float> leftSA(numFaces - 1);
	vector<cl_float> rightSA(numFaces - 1);
	vector< vector<vec3> > leftBB(numFaces - 1), rightBB(numFaces - 1);

	this->growAABBsForSAH(&faces, &leftBB, &rightBB, &leftSA, &rightSA);


	// Compute the SAH for each split position and choose the one with the lowest cost.
	// SAH = SA of node * ( SA left of split * faces left of split + SA right of split * faces right of split )

	int splitAfter = -1;
	cl_float newSAH;

	for (cl_uint i = 0; i < numFaces - 1; i++) {
		cl_float numFacesLeft = i + 1;
		cl_float numFacesRight = numFaces - i - 1;

		newSAH = leftSA[i] * numFacesLeft + rightSA[i] * numFacesRight;

		// Better split position found
		if (newSAH < *bestSAH) {
			*bestSAH = newSAH;
			// Up to (including) this face it is preferable to split.
			splitAfter = i + 1;
		}
	}


	// If a splitting index has been found, split the faces into two groups.

	if (splitAfter >= 0) {
		leftFaces->clear();
		rightFaces->clear();

		leftFaces->insert(leftFaces->begin(), faces.begin(), faces.begin() + splitAfter);
		rightFaces->insert(rightFaces->begin(), faces.begin() + splitAfter, faces.end());
	}
}

cl_float BVH::splitFaces(
	const vector<Tri> faces, const cl_float pos, const cl_uint axis,
	vector<Tri>* leftFaces, vector<Tri>* rightFaces
) {
	cl_float sah = FLT_MAX;
	vector<vec3> bbMinsL, bbMinsR, bbMaxsL, bbMaxsR;

	leftFaces->clear();
	rightFaces->clear();

	for (cl_uint i = 0; i < faces.size(); i++) {
		Tri tri = faces[i];
		vec3 cen = (tri.bbMin + tri.bbMax) * 0.5f;

		if (cen[axis] <= pos) {
			leftFaces->push_back(tri);
			bbMinsL.push_back(tri.bbMin);
			bbMaxsL.push_back(tri.bbMax);
		}
		else {
			rightFaces->push_back(tri);
			bbMinsR.push_back(tri.bbMin);
			bbMaxsR.push_back(tri.bbMax);
		}
	}

	// Just do it 50:50.
	if (leftFaces->size() == 0 || rightFaces->size() == 0) {
#ifdef __DEBUG__
		std::cout << "[BVH] Dividing faces by center left one side empty. Just doing it 50:50 now." << std::endl;
#endif
		bbMinsL.clear();
		bbMaxsL.clear();
		bbMinsR.clear();
		bbMaxsR.clear();
		leftFaces->clear();
		rightFaces->clear();

		for (cl_uint i = 0; i < faces.size(); i++) {
			Tri tri = faces[i];

			if (i < faces.size() / 2) {
				leftFaces->push_back(tri);
				bbMinsL.push_back(tri.bbMin);
				bbMaxsL.push_back(tri.bbMax);
			}
			else {
				rightFaces->push_back(tri);
				bbMinsR.push_back(tri.bbMin);
				bbMaxsR.push_back(tri.bbMax);
			}
		}
	}

	vec3 bbMinL, bbMinR, bbMaxL, bbMaxR;
	MathHelp::getAABB(bbMinsL, bbMaxsL, &bbMinL, &bbMaxL);
	cl_float leftSA = MathHelp::getSurfaceArea(bbMinL, bbMaxL);
	cl_float rightSA = MathHelp::getSurfaceArea(bbMinR, bbMaxR);

	sah = leftSA * leftFaces->size() + rightSA * rightFaces->size();

	// There has to be somewhere else something wrong.
	if (leftFaces->size() == 0 || rightFaces->size() == 0) {
		char msg[256];
		snprintf(
			msg, 256, "[BVH] Dividing faces 50:50 left one side empty. Faces: %lu.",
			faces.size()
		);
		cout << msg << "\n";

		sah = FLT_MAX;
	}

	return sah;
}

void BVH::splitNodes(
	const vector<BVHNode*> nodes, const cl_float pos, const cl_uint axis,
	vector<BVHNode*>* leftGroup, vector<BVHNode*>* rightGroup
) {
	for (cl_uint i = 0; i < nodes.size(); i++) {
		BVHNode* node = nodes[i];
		vec3 center = (node->bbMax - node->bbMin) / 2.0f;

		if (center[axis] < pos) {
			leftGroup->push_back(node);
		}
		else {
			rightGroup->push_back(node);
		}
	}

	// Just do it 50:50 then.
	if (leftGroup->size() == 0 || rightGroup->size() == 0) {
		//Logger::logDebugVerbose("[BVH] Dividing nodes by the given position left one side empty. Just doing it 50:50 now.");

		leftGroup->clear();
		rightGroup->clear();

		for (cl_uint i = 0; i < nodes.size(); i++) {
			if (i < nodes.size() / 2) {
				leftGroup->push_back(nodes[i]);
			}
			else {
				rightGroup->push_back(nodes[i]);
			}
		}
	}

	// There has to be somewhere else something wrong.
	if (leftGroup->size() == 0 || rightGroup->size() == 0) {
		char msg[256];
		snprintf(
			msg, 256, "[BVH] Dividing nodes 50:50 left one side empty. Nodes: %lu.", nodes.size()
		);
		cout << msg << "\n";
	}
}

void BVH::visualizeNextNode(
	const BVHNode* node, vector<cl_float>* vertices, vector<cl_uint>* indices
) {
	if (node == NULL) {
		return;
	}

	// Only visualize leaf nodes
	if (node->faces.size() > 0) {
		cl_uint i = vertices->size() / 3;

		// bottom
		vertices->push_back(node->bbMin[0]); vertices->push_back(node->bbMin[1]); vertices->push_back(node->bbMin[2]);
		vertices->push_back(node->bbMin[0]); vertices->push_back(node->bbMin[1]); vertices->push_back(node->bbMax[2]);
		vertices->push_back(node->bbMax[0]); vertices->push_back(node->bbMin[1]); vertices->push_back(node->bbMax[2]);
		vertices->push_back(node->bbMax[0]); vertices->push_back(node->bbMin[1]); vertices->push_back(node->bbMin[2]);

		// top
		vertices->push_back(node->bbMin[0]); vertices->push_back(node->bbMax[1]); vertices->push_back(node->bbMin[2]);
		vertices->push_back(node->bbMin[0]); vertices->push_back(node->bbMax[1]); vertices->push_back(node->bbMax[2]);
		vertices->push_back(node->bbMax[0]); vertices->push_back(node->bbMax[1]); vertices->push_back(node->bbMax[2]);
		vertices->push_back(node->bbMax[0]); vertices->push_back(node->bbMax[1]); vertices->push_back(node->bbMin[2]);

		cl_uint newIndices[24] = {
			// bottom
			i + 0, i + 1,
			i + 1, i + 2,
			i + 2, i + 3,
			i + 3, i + 0,
			// top
			i + 4, i + 5,
			i + 5, i + 6,
			i + 6, i + 7,
			i + 7, i + 4,
			// back
			i + 0, i + 4,
			i + 3, i + 7,
			// front
			i + 1, i + 5,
			i + 2, i + 6
		};
		indices->insert(indices->end(), newIndices, newIndices + 24);
	}

	// Proceed with left side
	this->visualizeNextNode(node->leftChild, vertices, indices);

	// Proceed width right side
	this->visualizeNextNode(node->rightChild, vertices, indices);
}

vector<BVHNode*> BVH::getContainerNodes() {
	return mContainerNodes;
}

cl_uint BVH::getDepth() {
	return mDepthReached;
}

vector<BVHNode*> BVH::getLeafNodes() {
	return mLeafNodes;
}

vector<BVHNode*> BVH::getNodes() {
	return mNodes;
}

BVHNode* BVH::getRoot() {
	return mRoot;
}

void BVH::visualize(vector<cl_float>* vertices, vector<cl_uint>* indices) {
	this->visualizeNextNode(mRoot, vertices, indices);
}

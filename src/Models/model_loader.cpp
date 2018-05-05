#include <Model/model_loader.h>

#include <iostream>

using namespace std;

ModelLoader::ModelLoader() {
	mObjParser = new ObjParser();
}

ModelLoader::~ModelLoader() {
	delete mObjParser;
}

void ModelLoader::getFacesOfObject(
	object3D object, vector<cl_uint4>* faces, cl_int offset
) {
	cl_uint a, b, c;

	for (cl_uint i = 0; i < object.facesV.size(); i += 3) {
		a = object.facesV[i + 0];
		b = object.facesV[i + 1];
		c = object.facesV[i + 2];

		cl_uint4 f = { a, b, c, offset + faces->size() };
		faces->push_back(f);
	}
}

void ModelLoader::getFaceNormalsOfObject(
	object3D object, vector<cl_uint4>* faceNormals, cl_int offset
) {
	cl_uint a, b, c;

	for (cl_uint i = 0; i < object.facesVN.size(); i += 3) {
		a = object.facesVN[i + 0];
		b = object.facesVN[i + 1];
		c = object.facesVN[i + 2];

		cl_uint4 fn = { a, b, c, offset + faceNormals->size() };
		faceNormals->push_back(fn);
	}
}

ObjParser* ModelLoader::getObjParser() {
	return mObjParser;
}

void ModelLoader::loadModel(string filepath, string filename) {
	char msg[256];
	snprintf(msg, 256, "[ModelLoader] Importing model \"%s\" ...", filename.c_str());
	cout << msg << std::endl;

	mObjParser->load(filepath, filename);

	vector<cl_uint> facesV = mObjParser->getFacesV();
	vector<cl_uint> facesVN = mObjParser->getFacesVN();
	vector<cl_float> vertices = mObjParser->getVertices();

	cout << "[ModelLoader] ... Done." << std::endl;
}
#pragma once

#include <CL/cl.hpp>
#include <vector>
#include <string>

#include <Model/obj_parser.h>
#include <utils.h>

using std::vector;
using std::string;

class ModelLoader {

public:
	ModelLoader();
	~ModelLoader();
	ObjParser* getObjParser();
	void loadModel(string filepath, string filename);

	static void getFaceNormalsOfObject(object3D object, vector<cl_uint4>* faceNormals, cl_int offset);
	static void getFacesOfObject(object3D object, vector<cl_uint4>* faces, cl_int offset);

private:
	ObjParser * mObjParser;

};

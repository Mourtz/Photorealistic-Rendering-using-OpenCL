#pragma once

#include <CL/cl.hpp>
#include <vector>
#include <string>

#include <Model/obj_parser.h>
#include <utils.h>

class ModelLoader {

public:
	ModelLoader();
	~ModelLoader();
	ObjParser* getObjParser();
	void loadModel(std::string filepath, std::string filename);

	static void getFaceNormalsOfObject(object3D object, std::vector<cl_uint4>* faceNormals, cl_int offset);
	static void getFacesOfObject(object3D object, std::vector<cl_uint4>* faces, cl_int offset);

private:
	ObjParser * mObjParser;

};

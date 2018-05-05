#pragma once

#include <CL/cl.hpp>
#include <GLFW/glfw3.h>
#include <vector>
#include <string>

using std::vector;
using std::string;

struct object3D {
	string oName;
	vector<cl_uint> facesV;
	vector<cl_uint> facesVN;
};

class ObjParser {

private:
	vector<object3D> mObjects;
	vector<cl_int> mFacesMtl;
	vector<cl_uint> mFacesV;
	vector<cl_uint> mFacesVN;
	vector<cl_uint> mFacesVT;
	vector<cl_float> mNormals;
	vector<cl_float> mTextures;
	vector<cl_float> mVertices;

	const string delimiter = " ";

protected:
	//void loadLights(string file);
	//void loadMtl(string file);
	void parseFace(
		string line, vector<cl_uint>* facesV,
		vector<cl_uint>* facesVN, vector<cl_uint>* facesVT
	);
	void parseVertex(string line, vector<cl_float>* vertices);
	void parseVertexNormal(string line, vector<cl_float>* normals);
	void parseVertexTexture(string line, vector<cl_float>* textures);

public:
	void load(string filepath, string filename);
	vector<cl_int> getFacesMtl();
	vector<cl_uint> getFacesV();
	vector<cl_uint> getFacesVN();
	vector<cl_uint> getFacesVT();
	//vector<light_t> getLights();
	//vector<material_t> getMaterials();
	vector<cl_float> getNormals();
	vector<object3D> getObjects();
	vector<cl_float> getTextureCoordinates();
	vector<cl_float> getVertices();
};

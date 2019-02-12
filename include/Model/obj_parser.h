#pragma once

#include <CL/cl.hpp>
#include <GLFW/glfw3.h>
#include <vector>
#include <string>

struct object3D {
	std::string oName;
	std::vector<cl_uint> facesV;
	std::vector<cl_uint> facesVN;
};

class ObjParser {

private:
	std::vector<object3D> mObjects;
	std::vector<cl_int> mFacesMtl;
	std::vector<cl_uint> mFacesV;
	std::vector<cl_uint> mFacesVN;
	std::vector<cl_uint> mFacesVT;
	std::vector<cl_float> mNormals;
	std::vector<cl_float> mTextures;
	std::vector<cl_float> mVertices;

	const std::string delimiter = " ";

protected:
	//void loadLights(std::string file);
	//void loadMtl(std::string file);
	void parseFace(
		std::string line, std::vector<cl_uint>* facesV,
		std::vector<cl_uint>* facesVN, std::vector<cl_uint>* facesVT
	);
	void parseVertex(std::string line, std::vector<cl_float>* vertices);
	void parseVertexNormal(std::string line, std::vector<cl_float>* normals);
	void parseVertexTexture(std::string line, std::vector<cl_float>* textures);

public:
	void load(std::string filepath, std::string filename);
	std::vector<cl_int> getFacesMtl();
	std::vector<cl_uint> getFacesV();
	std::vector<cl_uint> getFacesVN();
	std::vector<cl_uint> getFacesVT();
	//std::vector<light_t> getLights();
	//std::vector<material_t> getMaterials();
	std::vector<cl_float> getNormals();
	std::vector<object3D> getObjects();
	std::vector<cl_float> getTextureCoordinates();
	std::vector<cl_float> getVertices();
};

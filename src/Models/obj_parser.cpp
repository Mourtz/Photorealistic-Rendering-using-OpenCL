#include <Model/obj_parser.h>

#include <string_helper_functions.h>
#include <fstream>
#include <cstdlib>

std::vector<cl_int> ObjParser::getFacesMtl() {
	return mFacesMtl;
}

std::vector<cl_uint> ObjParser::getFacesV() {
	return mFacesV;
}

std::vector<cl_uint> ObjParser::getFacesVN() {
	return mFacesVN;
}

std::vector<cl_uint> ObjParser::getFacesVT() {
	return mFacesVT;
}

std::vector<cl_float> ObjParser::getNormals() {
	return mNormals;
}

std::vector<object3D> ObjParser::getObjects() {
	return mObjects;
}

std::vector<cl_float> ObjParser::getTextureCoordinates() {
	return mTextures;
}

std::vector<cl_float> ObjParser::getVertices() {
	return mVertices;
}

void ObjParser::load(std::string filepath, std::string filename) {
	using std::string;
	using std::vector;
	
	mObjects.clear();
	mFacesMtl.clear();
	mFacesV.clear();
	mFacesVN.clear();
	mFacesVT.clear();
	mNormals.clear();
	mTextures.clear();
	mVertices.clear();

	std::ifstream fileIn(filepath.append(filename).c_str());

	double timerStart = glfwGetTime();

	string line;
	while (getline(fileIn, line)) {

		//trim(line);

		// Ignore comment lines
		if (line[0] == '#') {
			continue;
		}

		// 3D object
		if (line[0] == 'o') {
			object3D o;
			vector<string> parts = split(line, delimiter);
			o.oName = parts[1];

			mObjects.push_back(o);
		}
		// Vertex data of some form
		else if (line[0] == 'v') {
			// vertex
			if (line[1] == ' ') {
				this->parseVertex(line, &mVertices);
			}
			// vertex normal
			else if (line[1] == 'n' && line[2] == ' ') {
				this->parseVertexNormal(line, &mNormals);
			}
			// vertex texture
			else if (line[1] == 't' && line[2] == ' ') {
				this->parseVertexTexture(line, &mTextures);
			}
		}
		// Faces
		else if (line[0] == 'f') {
			if (line[1] == ' ') {
				vector<cl_uint> lineFacesV, lineFacesVN, lineFacesVT;
				this->parseFace(line, &lineFacesV, &lineFacesVN, &lineFacesVT);

				mFacesV.insert(mFacesV.end(), lineFacesV.begin(), lineFacesV.end());
				mFacesVN.insert(mFacesVN.end(), lineFacesVN.begin(), lineFacesVN.end());
				mFacesVT.insert(mFacesVT.end(), lineFacesVT.begin(), lineFacesVT.end());

				if (mObjects.size() > 0) {
					object3D* op = &(mObjects[mObjects.size() - 1]);
					op->facesV.insert(op->facesV.end(), lineFacesV.begin(), lineFacesV.end());
					op->facesVN.insert(op->facesVN.end(), lineFacesVN.begin(), lineFacesVN.end());
				}
			}
		}
	}

	fileIn.close();

	char msg[256];
	snprintf(
		msg, 256, "[ObjParser] Loaded %lu vertices, %lu normals, and %lu faces in %g s.",
		mVertices.size() / 3, mFacesVN.size() / 3, mFacesV.size() / 3, (glfwGetTime() - timerStart)
	);

	std::cout << msg << std::endl;
}

void ObjParser::parseFace(std::string line, std::vector<cl_uint>* facesV, std::vector<cl_uint>* facesVN, std::vector<cl_uint>* facesVT) {
	using std::vector;
	using std::string;
	
	cl_uint numFaces = facesV->size();

	vector<string> parts = split(line, delimiter);

	for (cl_uint i = 1; i < parts.size(); i++) {
		cl_uint a;

		vector<string> e0 = split(parts[i], "/");
		vector<string> e1 = split(parts[i], "//");

		// "v//vn"
		if (e1.size() == 2) {
			// v
			a = atol(e1[0].c_str());
			a = (a < 0) ? numFaces - a : a;
			facesV->push_back(a - 1);

			// vn
			a = atol(e1[1].c_str());
			a = (a < 0) ? numFaces - a : a;
			facesVN->push_back(a - 1);
		}
		else {
			// "v"
			a = atol(e0[0].c_str());
			a = (a < 0) ? numFaces - a : a;
			facesV->push_back(a - 1);

			// "v/vt"
			if (e0.size() >= 2) {
				a = atol(e0[1].c_str());
				a = (a < 0) ? numFaces - a : a;
				facesVT->push_back(a - 1);
			}
			// "v/vt/vn"
			if (e0.size() >= 3) {
				a = atol(e0[2].c_str());
				a = (a < 0) ? numFaces - a : a;
				facesVN->push_back(a - 1);
			}
		}
	}
}

inline void ObjParser::parseVertex(std::string line, std::vector<cl_float>* vertices) {
	const std::vector<std::string> parts = split(line, delimiter);

	vertices->push_back(atof(parts[1].c_str()));
	vertices->push_back(atof(parts[2].c_str()));
	vertices->push_back(atof(parts[3].c_str()));
}

inline void ObjParser::parseVertexNormal(std::string line, std::vector<cl_float>* normals) {
	const std::vector<std::string> parts = split(line, delimiter);

	normals->push_back(atof(parts[1].c_str()));
	normals->push_back(atof(parts[2].c_str()));
	normals->push_back(atof(parts[3].c_str()));
}

inline void ObjParser::parseVertexTexture(std::string line, std::vector<cl_float>* texCoords) {
	const std::vector<std::string> parts = split(line, delimiter);

	const float weight = (parts.size() >= 4) ? atof(parts[3].c_str()) : 0.0f;

	texCoords->push_back(atof(parts[1].c_str()));
	texCoords->push_back(atof(parts[2].c_str()));
	texCoords->push_back(weight);
}
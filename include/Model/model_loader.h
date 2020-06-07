#pragma once

#include <CL/cl.hpp>
#include <vector>
#include <string>
#include <utility>
#include <map>

#include <Model/obj_parser.h>
#include <utils.h>

#include <assimp/Importer.hpp> // C++ importer interface

struct aiScene;
struct aiMesh;

namespace IO
{
		typedef std::pair<std::vector<unsigned int>, std::vector<float>> MeshData;
		typedef std::vector<MeshData> SceneData;
		
		static const void *getPositionsPtr(const MeshData &data)
		{
			return &data.second[0];
		}
		static const void *getNormalsPtr(const MeshData &data)
		{
			return &data.second[3 * data.first[1]];
		}
		static const void *getTextureCoordsPtr(const MeshData &data)
		{
			return &data.second[6 * data.first[1]];
		}
		static const void *getTangentsPtr(const MeshData &data)
		{
			return &data.second[8 * data.first[1]];
		}

		static std::vector<unsigned int> getIndices(const MeshData &data)
		{
			return std::vector<unsigned int>(data.first.cbegin() + 2, data.first.cend());
		}
		static std::vector<float> getPositions(const MeshData &data)
		{
			return std::vector<float>(data.second.cbegin(), data.second.cbegin() + data.first[1] * 3);
		}
		static std::vector<float> getNormals(const MeshData &data)
		{
			return std::vector<float>(data.second.cbegin() + data.first[1] * 3, data.second.cbegin() + data.first[1] * 6);
		}
		static std::vector<float> getTextureCoords(const MeshData &data)
		{
			return std::vector<float>(data.second.cbegin() + data.first[1] * 6, data.second.cbegin() + data.first[1] * 8);
		}
		static std::vector<float> getTangents(const MeshData &data)
		{
			return std::vector<float>(data.second.cbegin() + data.first[1] * 8, data.second.cbegin() + data.first[1] * 11);
		}
	class ModelLoader
	{

	public:
		ModelLoader();
		~ModelLoader();
		void loadModel(std::string filepath, std::string filename);

		static void getFaceNormalsOfObject(object3D object, std::vector<cl_uint4> &faceNormals, cl_int offset);
		static void getFacesOfObject(object3D object, std::vector<cl_uint4> &faces, cl_int offset);

		bool ImportFromFile(const std::string &filepath, std::unique_ptr<SceneData> &sceneData);
		std::unique_ptr<SceneData> ProcessData(const aiScene *scene);

		const MeshData assimpGetMeshData(const aiMesh *mesh);
	private:
		// Create an instance of the Importer class
		Assimp::Importer importer;
	};
} // namespace IO

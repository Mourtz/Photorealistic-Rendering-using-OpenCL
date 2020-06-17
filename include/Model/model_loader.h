#pragma once

#include <CL/cl.hpp>
#include <vector>
#include <array>
#include <string>
#include <utility>
#include <map>
#include <utils.h>

#include <Math/linear_algebra.h>
#include <assimp/Importer.hpp> // C++ importer interface

struct aiScene;
struct aiMesh;

namespace IO
{
	struct Vertex
	{
		cl_float3 pos;
		cl_float3 nor;
		cl_float3 tangent;
		cl_float2 uv;

		cl_uint id;

		Vertex() {}
		Vertex(cl_float3 _pos, cl_float3 _nor, cl_float2 _uv, cl_float3 _tangent, cl_uint _id) : pos(_pos), nor(_nor), uv(_uv), tangent(_tangent), id(_id) {}
	};

	struct Face
	{
		std::array<Vertex, 3> points;

		Face() {}
		Face(Vertex v0, Vertex v1, Vertex v2)
		{
			points[0] = v0;
			points[1] = v1;
			points[2] = v2;
		}
	};

	struct Mesh{
		std::vector<Face> faces;

		Mesh(){}
		Mesh(std::vector<Face>& _faces) : faces(_faces) {}
	};

	struct Scene{
		std::vector<Mesh> meshes;

		Scene(){}
		Scene(std::vector<Mesh>& _meshes) : meshes(_meshes) {}
	};

	// Raw Data
	typedef std::pair<std::vector<unsigned int>, std::vector<float>> MeshData;
	typedef std::vector<MeshData> SceneData;

	class ModelLoader
	{

	public:
		ModelLoader() {}
		~ModelLoader() {}

		bool ImportFromFile(const std::string &filepath);
		const std::shared_ptr<SceneData> getData() const {
			return sceneData;
		}
		const std::shared_ptr<Scene> getFaces();

		std::vector<unsigned int> getIndices() const;
		std::vector<cl_uint4> getIndices4() const;
		std::vector<unsigned int> getIndicesAt(unsigned index) const;

		std::vector<float> getPositions() const;
		std::vector<cl_float4> getPositions4() const;
		std::vector<float> getPositionsAt(unsigned index) const;

		std::vector<float> getNormals() const;
		std::vector<cl_float4> getNormals4() const;
		std::vector<float> getNormalsAt(unsigned index) const;

		std::vector<float> getTextureCoords() const;
		std::vector<cl_float4> getTextureCoords4() const;
		// std::vector<float> getTextureCoordsAt(unsigned index) const;

		std::vector<float> getTangents() const;
		std::vector<cl_float4> getTangents4() const;
		// std::vector<float> getTangentsAt(unsigned index) const;

	private:
		void updateSceneData(const aiScene *scene);
		const MeshData assimpGetMeshData(const aiMesh *mesh);

		// raw data
		std::shared_ptr<SceneData> sceneData;
		std::shared_ptr<Scene> scene;

		// Create an instance of the Importer class
		Assimp::Importer importer;

		// get pointers to data
		const void *getPositionsPtr(const MeshData &data);
		const void *getNormalsPtr(const MeshData &data);
		const void *getTextureCoordsPtr(const MeshData &data);
		const void *getTangentsPtr(const MeshData &data);

		std::vector<unsigned int> getIndices(const MeshData &data) const;
		std::vector<cl_uint4> getIndices4(const MeshData &data) const;
	
		std::vector<float> getPositions(const MeshData &data) const;
		std::vector<cl_float4> getPositions4(const MeshData &data) const;

		std::vector<float> getNormals(const MeshData &data) const;
		std::vector<cl_float4> getNormals4(const MeshData &data) const;

		std::vector<float> getTextureCoords(const MeshData &data) const;
		std::vector<cl_float4> getTextureCoords4(const MeshData &data) const;

		std::vector<float> getTangents(const MeshData &data) const;
		std::vector<cl_float4> getTangents4(const MeshData &data) const;
	};
} // namespace IO

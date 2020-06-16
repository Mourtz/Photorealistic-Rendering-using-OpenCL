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
		cl_float2 uv;
		cl_float3 tangent;

		cl_uint id;

		Vertex() {}
		Vertex(cl_float3 _pos, cl_float3 _nor, cl_float2 _uv, cl_float3 _tangent, cl_uint _id) : pos(_pos), nor(_nor), uv(_uv), tangent(_tangent), id(_id) {}
	};

	struct Face
	{
		union {
			std::array<Vertex, 3> vertex;
			std::array<Vertex, 3> points;
		};

		Face() {}
		Face(Vertex v0, Vertex v1, Vertex v2)
		{
			vertex[0] = v0;
			vertex[1] = v1;
			vertex[2] = v2;
		}
	};

	struct Mesh{
		std::vector<Face> faces;
	};

	struct Scene{
		std::vector<Mesh> meshes;
	};

	// Data
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

	static std::vector<cl_uint4> getIndices4(const MeshData &data)
	{
		std::vector<cl_uint4> res;

		const auto &indices = getIndices(data);
		for (int i = 0; i < indices.size();)
		{
			res.push_back({indices[i++], indices[i++], indices[i++], 0});
		}
		return res;
	}

	static std::vector<unsigned int> getIndices(const std::shared_ptr<IO::SceneData> &sceneData)
	{
		std::vector<unsigned int> res;

		for (const auto &mesh : *sceneData)
		{
			const std::vector<unsigned int> &faces = getIndices(mesh);
			res.insert(res.end(), faces.begin(), faces.end());
		}

		return res;
	}

	static std::vector<cl_uint4> getIndices4(const std::shared_ptr<IO::SceneData> &sceneData)
	{
		std::vector<cl_uint4> res;

		for (const auto &mesh : *sceneData)
		{
			const auto &faces = getIndices4(mesh);
			res.insert(res.end(), faces.begin(), faces.end());
		}

		return res;
	}

	//-------------------------------------------------------------------------------------------------------

	static std::vector<float> getPositions(const MeshData &data)
	{
		return std::vector<float>(data.second.cbegin(), data.second.cbegin() + data.first[1] * 3);
	}

	static std::vector<cl_float4> getPositions4(const MeshData &data)
	{
		std::vector<cl_float4> res;

		const auto &positions = getPositions(data);
		for (int i = 0; i < positions.size();)
		{
			res.push_back({positions[i++], positions[i++], positions[i++], 0.0f});
		}
		return res;
	}

	static std::vector<float> getPositions(const std::shared_ptr<IO::SceneData> &sceneData)
	{
		std::vector<float> res;

		for (const auto &mesh : *sceneData)
		{
			const std::vector<float> &pos = getPositions(mesh);
			res.insert(res.end(), pos.begin(), pos.end());
		}

		return res;
	}

	static std::vector<cl_float4> getPositions4(const std::shared_ptr<IO::SceneData> &sceneData)
	{
		std::vector<cl_float4> res;

		for (const auto &mesh : *sceneData)
		{
			const auto &pos = getPositions4(mesh);
			res.insert(res.end(), pos.begin(), pos.end());
		}

		return res;
	}

	//-------------------------------------------------------------------------------------------------------

	static std::vector<float> getNormals(const MeshData &data)
	{
		return std::vector<float>(data.second.cbegin() + data.first[1] * 3, data.second.cbegin() + data.first[1] * 6);
	}

	static std::vector<cl_float4> getNormals4(const MeshData &data)
	{
		std::vector<cl_float4> res;

		const auto &normals = getNormals(data);
		for (int i = 0; i < normals.size();)
		{
			res.push_back({normals[i++], normals[i++], normals[i++], 0.0f});
		}
		return res;
	}

	static std::vector<float> getNormals(const std::shared_ptr<IO::SceneData> &sceneData)
	{
		std::vector<float> res;

		for (const auto &mesh : *sceneData)
		{
			const std::vector<float> &nor = getNormals(mesh);
			res.insert(res.end(), nor.begin(), nor.end());
		}

		return res;
	}

	static std::vector<cl_float4> getNormals4(const std::shared_ptr<IO::SceneData> &sceneData)
	{
		std::vector<cl_float4> res;

		for (const auto &mesh : *sceneData)
		{
			const auto &nor = getNormals4(mesh);
			res.insert(res.end(), nor.begin(), nor.end());
		}

		return res;
	}

	//-------------------------------------------------------------------------------------------------------

	static std::vector<float> getTextureCoords(const MeshData &data)
	{
		return std::vector<float>(data.second.cbegin() + data.first[1] * 6, data.second.cbegin() + data.first[1] * 8);
	}

	static std::vector<cl_float4> getTextureCoords4(const MeshData &data)
	{
		std::vector<cl_float4> res;

		const auto &tex_coord = getTextureCoords(data);
		for (int i = 0; i < tex_coord.size();)
		{
			res.push_back({tex_coord[i++], tex_coord[i++], tex_coord[i++], 0.0f});
		}
		return res;
	}

	static std::vector<float> getTextureCoords(const std::shared_ptr<IO::SceneData> &sceneData)
	{
		std::vector<float> res;

		for (const auto &mesh : *sceneData)
		{
			const std::vector<float> &uv = getTextureCoords(mesh);
			res.insert(res.end(), uv.begin(), uv.end());
		}

		return res;
	}

	static std::vector<cl_float4> getTextureCoords4(const std::shared_ptr<IO::SceneData> &sceneData)
	{
		std::vector<cl_float4> res;

		for (const auto &mesh : *sceneData)
		{
			const auto &uv = getTextureCoords4(mesh);
			res.insert(res.end(), uv.begin(), uv.end());
		}

		return res;
	}

	//-------------------------------------------------------------------------------------------------------

	static std::vector<float> getTangents(const MeshData &data)
	{
		return std::vector<float>(data.second.cbegin() + data.first[1] * 8, data.second.cbegin() + data.first[1] * 11);
	}

	static std::vector<cl_float4> getTangents4(const MeshData &data)
	{
		std::vector<cl_float4> res;

		const auto &tg = getTangents(data);
		for (int i = 0; i < tg.size();)
		{
			res.push_back({tg[i++], tg[i++], tg[i++], 0.0f});
		}
		return res;
	}

	static std::vector<float> getTangents(const std::shared_ptr<IO::SceneData> &sceneData)
	{
		std::vector<float> res;

		for (const auto &mesh : *sceneData)
		{
			const std::vector<float> &tangent = getTangents(mesh);
			res.insert(res.end(), tangent.begin(), tangent.end());
		}

		return res;
	}

	static std::vector<cl_float4> getTangents4(const std::shared_ptr<IO::SceneData> &sceneData)
	{
		std::vector<cl_float4> res;

		for (const auto &mesh : *sceneData)
		{
			const auto &tangent = getTangents4(mesh);
			res.insert(res.end(), tangent.begin(), tangent.end());
		}

		return res;
	}
	//-------------------------------------------------------------------------------------------------------

	static Scene getFaces(const std::shared_ptr<IO::SceneData> &sceneData)
	{
		Scene res;

		unsigned int offset = 0;

		const auto &vertices = getPositions(sceneData);
		const auto &normals = getNormals(sceneData);
		const auto &uvs = getTextureCoords(sceneData);
		const auto &tangents = getTangents(sceneData);

		for (const auto &meshData : *sceneData)
		{
			Mesh mesh;
			for (const auto &f : getIndices4(meshData))
			{
				std::array<Vertex, 3> verts;
				for (int i = 0; i < 3; ++i)
				{
					verts[i] = Vertex({vertices[offset + f.s[i]],
									   vertices[offset + f.s[i] + 1],
									   vertices[offset + f.s[i] + 2]},
									  {normals[offset + f.s[i]],
									   normals[offset + f.s[i] + 1],
									   normals[offset + f.s[i] + 2]},
									  {
										  uvs[offset + f.s[i]],
										  uvs[offset + f.s[i] + 1],
									  },
									  {tangents[offset + f.s[i]],
									   tangents[offset + f.s[i] + 1],
									   tangents[offset + f.s[i] + 2]},
									  offset + f.s[i]);
				}
				mesh.faces.push_back(Face(verts[0], verts[1], verts[2]));
			}
			offset += meshData.first[1];
			res.meshes.push_back(mesh);
		}

		return res;
	}

	class ModelLoader
	{

	public:
		ModelLoader() {}
		~ModelLoader() {}

		bool ImportFromFile(const std::string &filepath);
		const std::shared_ptr<SceneData> getData() const {
			return sceneData;
		}
	private:
		std::shared_ptr<SceneData> ProcessData(const aiScene *scene);
		const MeshData assimpGetMeshData(const aiMesh *mesh);

		std::shared_ptr<SceneData> sceneData;

		// Create an instance of the Importer class
		Assimp::Importer importer;
	};
} // namespace IO

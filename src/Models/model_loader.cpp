#include <Model/model_loader.h>

#include <iostream>
#include <assimp/scene.h>		// Output data structure
#include <assimp/postprocess.h> // Post processing flags

#ifdef PROFILING
#include <iomanip>		// std::setprecision
#include <GLFW/glfw3.h> // glfwGetTime
#endif

namespace CL_RAYTRACER
{
namespace IO
{
	bool ModelLoader::ImportFromFile(const std::string &filepath)
	{
		// free cached scene
		sceneData.reset();

#ifdef PROFILING
		std::cout << "Loading " << filepath << " ..." << std::endl;
		double start = glfwGetTime();
#endif
		//check if file exists
		std::ifstream fin(filepath.c_str());
		if (!fin.fail())
		{
			fin.close();
		}
		else
		{
			printf("Couldn't open file: %s\n", filepath.c_str());
			printf("%s\n", importer.GetErrorString());
			return false;
		}

		const aiScene *scene = importer.ReadFile(filepath, aiProcessPreset_TargetRealtime_Quality);

		// If the import failed, report it
		if (!scene)
		{
			printf("%s\n", importer.GetErrorString());
			return false;
		}

		sceneData.reset(new SceneData);
		updateSceneData(scene->mRootNode, scene);

#ifdef PROFILING
		std::cout << std::setprecision(4) << "Loaded " << filepath << " at "
					<< (glfwGetTime() - start) << "s ..." << std::endl;
#endif
		return true;
	}

	// from https://github.com/JoeyDeVries/LearnOpenGL/blob/0a8d6e582c99d90ad68181befe44c4589063ab20/includes/learnopengl/model.h
	void ModelLoader::updateSceneData(aiNode *node, const aiScene *scene)
	{
		// process each mesh located at the current node
        for(unsigned int i = 0; i < node->mNumMeshes; i++)
        {
            // the node object only contains indices to index the actual objects in the scene. 
            // the scene contains all the data, node is just to keep stuff organized (like relations between nodes).
            aiMesh* mesh = scene->mMeshes[node->mMeshes[i]];
			sceneData->push_back(assimpGetMeshData(mesh));
			std::cout << "::::::::PROCESSING =>" << mesh->mName.C_Str() << " , Faces: " << mesh->mNumFaces << std::endl;
        }

        // after we've processed all of the meshes (if any) we then recursively process each of the children nodes
        for(unsigned int i = 0; i < node->mNumChildren; i++)
        {
            updateSceneData(node->mChildren[i], scene);
        }
	}

	const MeshData ModelLoader::assimpGetMeshData(const aiMesh *mesh)
	{
		MeshData res;

		// total faces
		res.first.push_back(mesh->mNumFaces);
		// total vertices
		res.first.push_back(mesh->mNumVertices);

		for (unsigned int f = 0; f < mesh->mNumFaces; f++)
		{
			aiFace *face = &mesh->mFaces[f];
			for (unsigned int i = 0; i < face->mNumIndices; ++i)
			{
				if (i > 2)
				{
					std::cerr << "there's only support for triangles at the moment!" << std::endl;
					break;
				}
				res.first.emplace_back(face->mIndices[i]);
			}
		}

		for (unsigned int v = 0; v < mesh->mNumVertices; ++v)
		{
			res.second.push_back(mesh->mVertices[v].x);
			res.second.push_back(mesh->mVertices[v].y);
			res.second.push_back(mesh->mVertices[v].z);
		}

		for (unsigned int v = 0; v < mesh->mNumVertices; ++v)
		{
			res.second.push_back(mesh->mNormals[v].x);
			res.second.push_back(mesh->mNormals[v].y);
			res.second.push_back(mesh->mNormals[v].z);
		}

		for (unsigned int v = 0; v < mesh->mNumVertices; ++v)
		{
			if (mesh->HasTextureCoords(0))
			{
				res.second.push_back(mesh->mTextureCoords[0][v].x);
				res.second.push_back(mesh->mTextureCoords[0][v].y);
			}
			else
			{
				res.second.push_back(0);
				res.second.push_back(0);
			}
		}

		if (mesh->HasTangentsAndBitangents())
		{
			for (unsigned int v = 0; v < mesh->mNumVertices; ++v)
			{
				res.second.push_back(mesh->mTangents[v].x);
				res.second.push_back(mesh->mTangents[v].y);
				res.second.push_back(mesh->mTangents[v].z);
			}
		}
		else
		{
			for (unsigned int v = 0; v < mesh->mNumVertices; ++v)
			{
				res.second.push_back(0);
				res.second.push_back(0);
				res.second.push_back(0);
			}
		}

		return res;
	}

	const std::unique_ptr<Scene> ModelLoader::getFaces()
	{
		std::unique_ptr<Scene> scene = std::make_unique<Scene>();

		for (std::size_t m = 0; m < sceneData->size(); ++m)
		{
			const MeshData &meshData = (*sceneData)[m];
			const auto &vertices = getPositions4(meshData);
			const auto &normals = getNormals4(meshData);

			Mesh mesh;
			for (const auto &f : getIndices4(meshData))
			{
				std::array<Vertex, 3> verts;
				for (std::size_t i = 0; i < 3; ++i)
				{
					const std::size_t index = f.s[i];
					verts[i].pos = vertices[index];
					verts[i].nor = normals[index];
				}
				mesh.faces.emplace_back(verts[0], verts[1], verts[2]);
			}
			scene->meshes.push_back(mesh);
		}

		return scene;
	}

	const void *ModelLoader::getPositionsPtr(const MeshData &data)
	{
		return &data.second[0];
	}

	const void *ModelLoader::getNormalsPtr(const MeshData &data)
	{
		return &data.second[3 * data.first[1]];
	}

	const void *ModelLoader::getTextureCoordsPtr(const MeshData &data)
	{
		return &data.second[6 * data.first[1]];
	}

	const void *ModelLoader::getTangentsPtr(const MeshData &data)
	{
		return &data.second[8 * data.first[1]];
	}

	std::vector<unsigned int> ModelLoader::getIndices(const MeshData &data) const
	{
		return std::vector<unsigned int>(data.first.begin() + 2, data.first.end());
	}

	std::vector<cl_uint4> ModelLoader::getIndices4(const MeshData &data) const
	{
		std::vector<cl_uint4> res;

		const auto &indices = getIndices(data);

		if(indices.size()%3 != 0){
			std::cerr << "[Error]: indices%3 != 0 !!!!!!!!!!" << std::endl;
		}

		for (unsigned int i = 0; i < indices.size();)
		{
			res.push_back({indices[i++], indices[i++], indices[i++], 0U});
		}
		return res;
	}

	std::vector<unsigned int> ModelLoader::getIndices() const
	{
		std::vector<unsigned int> res;

		for (const auto &meshData : *sceneData)
		{
			const std::vector<unsigned int> &faces = getIndices(meshData);
			res.insert(res.end(), faces.begin(), faces.end());
		}

		return res;
	}

	std::vector<cl_uint4> ModelLoader::getIndices4() const
	{
		std::vector<cl_uint4> res;

		for (const auto &meshData : *sceneData)
		{
			const auto &faces = getIndices4(meshData);
			res.insert(res.end(), faces.begin(), faces.end());
		}

		return res;
	}

	std::vector<unsigned int> ModelLoader::getIndicesAt(unsigned index) const
	{
		return getIndices(sceneData->at(index));
	}

	std::vector<float> ModelLoader::getPositions(const MeshData &data) const
	{
		return std::vector<float>(data.second.begin(), data.second.begin() + data.first[1] * 3);
	}

	std::vector<cl_float4> ModelLoader::getPositions4(const MeshData &data) const
	{
		std::vector<cl_float4> res;

		const auto &positions = getPositions(data);
		for (int i = 0; i < positions.size();)
		{
			res.push_back({positions[i++], positions[i++], positions[i++], 0.0f});
		}
		return res;
	}

	std::vector<float> ModelLoader::getPositions() const
	{
		std::vector<float> res;

		for (const auto &mesh : *sceneData)
		{
			const std::vector<float> &pos = getPositions(mesh);
			res.insert(res.end(), pos.begin(), pos.end());
		}

		return res;
	}

	std::vector<cl_float4> ModelLoader::getPositions4() const
	{
		std::vector<cl_float4> res;

		for (const auto &mesh : *sceneData)
		{
			const auto &pos = getPositions4(mesh);
			res.insert(res.end(), pos.begin(), pos.end());
		}

		return res;
	}

	std::vector<float> ModelLoader::getPositionsAt(unsigned index) const
	{
		return getPositions(sceneData->at(index));
	}

	std::vector<float> ModelLoader::getNormals(const MeshData &data) const
	{
		return std::vector<float>(data.second.begin() + data.first[1] * 3, data.second.begin() + data.first[1] * 6);
	}

	std::vector<cl_float4> ModelLoader::getNormals4(const MeshData &data) const
	{
		std::vector<cl_float4> res;

		const auto &normals = getNormals(data);
		for (int i = 0; i < normals.size();)
		{
			res.push_back({normals[i++], normals[i++], normals[i++], 0.0f});
		}
		return res;
	}

	std::vector<float> ModelLoader::getNormals() const
	{
		std::vector<float> res;

		for (const auto &mesh : *sceneData)
		{
			const std::vector<float> &nor = getNormals(mesh);
			res.insert(res.end(), nor.begin(), nor.end());
		}

		return res;
	}

	std::vector<cl_float4> ModelLoader::getNormals4() const
	{
		std::vector<cl_float4> res;

		for (const auto &mesh : *sceneData)
		{
			const auto &nor = getNormals4(mesh);
			res.insert(res.end(), nor.begin(), nor.end());
		}

		return res;
	}

	std::vector<float> ModelLoader::getNormalsAt(unsigned index) const
	{
		return getNormals(sceneData->at(index));
	}

	std::vector<float> ModelLoader::getTextureCoords(const MeshData &data) const
	{
		return std::vector<float>(data.second.begin() + data.first[1] * 6, data.second.begin() + data.first[1] * 8);
	}

	std::vector<cl_float4> ModelLoader::getTextureCoords4(const MeshData &data) const
	{
		std::vector<cl_float4> res;

		const auto &tex_coord = getTextureCoords(data);
		for (int i = 0; i < tex_coord.size();)
		{
			res.push_back({tex_coord[i++], tex_coord[i++], tex_coord[i++], 0.0f});
		}
		return res;
	}

	std::vector<float> ModelLoader::getTextureCoords() const
	{
		std::vector<float> res;

		for (const auto &mesh : *sceneData)
		{
			const std::vector<float> &uv = getTextureCoords(mesh);
			res.insert(res.end(), uv.begin(), uv.end());
		}

		return res;
	}

	std::vector<cl_float4> ModelLoader::getTextureCoords4() const
	{
		std::vector<cl_float4> res;

		for (const auto &mesh : *sceneData)
		{
			const auto &uv = getTextureCoords4(mesh);
			res.insert(res.end(), uv.begin(), uv.end());
		}

		return res;
	}

	std::vector<float> ModelLoader::getTangents(const MeshData &data) const
	{
		return std::vector<float>(data.second.begin() + data.first[1] * 8, data.second.begin() + data.first[1] * 11);
	}

	std::vector<cl_float4> ModelLoader::getTangents4(const MeshData &data) const
	{
		std::vector<cl_float4> res;

		const auto &tg = getTangents(data);
		for (int i = 0; i < tg.size();)
		{
			res.push_back({tg[i++], tg[i++], tg[i++], 0.0f});
		}
		return res;
	}

	std::vector<float> ModelLoader::getTangents() const
	{
		std::vector<float> res;

		for (const auto &mesh : *sceneData)
		{
			const std::vector<float> &tangent = getTangents(mesh);
			res.insert(res.end(), tangent.begin(), tangent.end());
		}

		return res;
	}

	std::vector<cl_float4> ModelLoader::getTangents4() const
	{
		std::vector<cl_float4> res;

		for (const auto &mesh : *sceneData)
		{
			const auto &tangent = getTangents4(mesh);
			res.insert(res.end(), tangent.begin(), tangent.end());
		}

		return res;
	}
} // namespace IO
} // namespace CL_RAYTRACER

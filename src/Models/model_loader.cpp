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
		scene.reset();
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

		updateSceneData(scene);

#ifdef PROFILING
		std::cout << std::setprecision(4) << "Loaded " << filepath << " at "
					<< (glfwGetTime() - start) << "s ..." << std::endl;
#endif
		return true;
	}

	void ModelLoader::updateSceneData(const aiScene *scene)
	{
		sceneData.reset(new SceneData);

		bool repeat = true;

		std::vector<const aiNode *> nodeBuff;
		nodeBuff.push_back(scene->mRootNode);

		// I raise all nodes tree to the root level
		while (repeat)
		{
			for (unsigned int a = 0; a < nodeBuff.size(); a++)
			{
				const aiNode *modelNode = nodeBuff.at(a);
				if (modelNode->mNumChildren > 0)
					for (unsigned int c = 0; c < modelNode->mNumChildren; c++)
					{
						nodeBuff.push_back(modelNode->mChildren[c]);
					}

				else
					repeat = false;
			}
		}

		// Get node information from the root level (all nodes)
		for (unsigned int a = 0; a < nodeBuff.size(); a++)
		{
			const aiNode *modelNode = nodeBuff.at(a);

			if (modelNode->mNumMeshes > 0)
				for (unsigned int b = 0; b < modelNode->mNumMeshes; b++)
				{
					sceneData->push_back(assimpGetMeshData(scene->mMeshes[b]));
					std::cout << "::::::::PROCESSING =>" << scene->mMeshes[b]->mName.C_Str() << " , Faces: " << scene->mMeshes[b]->mNumFaces << std::endl;
				}
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

	const std::shared_ptr<Scene> ModelLoader::getFaces()
	{
		scene.reset(new Scene);
		std::size_t offset = 0;

		const std::vector<float> &vertices = getPositions();
		const std::vector<float> &normals = getNormals();
		// const std::vector<float> &uvs = getTextureCoords();
		// const std::vector<float> &tangents = getTangents();

		for (std::size_t m = 0; m < sceneData->size(); ++m)
		{
			const MeshData &meshData = (*sceneData)[m];

			Mesh mesh;
			for (const auto &f : getIndices4(meshData))
			{
				std::array<Vertex, 3> verts;
				for (std::size_t i = 0; i < 3; ++i)
				{
					const std::size_t index = (offset + f.s[i])*3;
					verts[i].pos = {vertices[index], vertices[index+1], vertices[index+2]};
					verts[i].nor = {normals[index], normals[index+1], normals[index+2]};
				}
				mesh.faces.emplace_back(verts[0], verts[1], verts[2]);
			}
			scene->meshes.push_back(mesh);
			break; // only 1 mesh for the moment
			offset += meshData.first[1];
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

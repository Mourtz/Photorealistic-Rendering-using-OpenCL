#include <Model/model_loader.h>

#include <iostream>
#include <assimp/scene.h>		// Output data structure
#include <assimp/postprocess.h> // Post processing flags

#ifdef PROFILING
#include <iomanip>      // std::setprecision
#include <GLFW/glfw3.h> // glfwGetTime
#endif

/*
extern cl::Context context;
extern cl::CommandQueue queue;
extern cl::Program bvh_program;
*/
namespace IO
{
	bool ModelLoader::ImportFromFile(const std::string &filepath)
	{
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

		sceneData = ProcessData(scene);

#ifdef PROFILING
		std::cout << std::setprecision(4) << "Loaded " << filepath << " at "
			<< (glfwGetTime()-start) << "s ..." << std::endl;
#endif
		return true;
	}

	std::shared_ptr<SceneData> ModelLoader::ProcessData(const aiScene *scene)
	{
		std::shared_ptr<SceneData> ret = std::make_shared<SceneData>();

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
					ret->push_back(assimpGetMeshData(scene->mMeshes[b]));
					std::cout << "::::::::PROCESSING =>" << scene->mMeshes[b]->mName.C_Str() << " , Faces: " << scene->mMeshes[b]->mNumFaces << std::endl;
				}
		}
		return ret;
	}

	const MeshData ModelLoader::assimpGetMeshData(const aiMesh *mesh)
	{
		MeshData res;

		res.first.push_back(mesh->mNumFaces);
		res.first.push_back(mesh->mNumVertices);

		for (unsigned int f = 0; f < mesh->mNumFaces; f++)
		{
			aiFace *face = &mesh->mFaces[f];
			res.first.push_back(face->mIndices[0]);
			res.first.push_back(face->mIndices[1]);
			res.first.push_back(face->mIndices[2]);
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
		} else {
			res.second.push_back(0);
			res.second.push_back(0);
			res.second.push_back(0);
		}

		return res;
	}

} // namespace IO

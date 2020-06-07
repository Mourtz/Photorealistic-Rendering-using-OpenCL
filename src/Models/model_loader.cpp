#include <Model/model_loader.h>

#include <iostream>
#include <assimp/scene.h>		// Output data structure
#include <assimp/postprocess.h> // Post processing flags

/*
extern cl::Context context;
extern cl::CommandQueue queue;
extern cl::Program bvh_program;
*/
namespace IO
{
	ModelLoader::ModelLoader(){	}

	ModelLoader::~ModelLoader(){}

	void ModelLoader::getFacesOfObject(
		object3D object, std::vector<cl_uint4> &faces, cl_int offset)
	{
#if 0
	cl::Kernel kernel = cl::Kernel(bvh_program, "getFacesOfObject");

	cl::Buffer b_facesV = cl::Buffer(
		context, 
		CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, 
		object.facesV.size()*sizeof(uint),
		&object.facesV[0]
	);
	kernel.setArg(0, b_facesV);

	faces = std::vector<cl_uint4>(object.facesV.size()/3);
	cl::Buffer b_faces = cl::Buffer(
		context, 
		CL_MEM_WRITE_ONLY, 
		(object.facesV.size()/3)*sizeof(cl_uint4)
	);
	kernel.setArg(1, b_faces);
	kernel.setArg(2, offset);

	// launch the kernel
	// std::cout << queue.enqueueWriteBuffer(b_facesV, CL_TRUE, 0, object.facesV.size()*sizeof(uint),object.facesV.data());
	queue.enqueueNDRangeKernel(kernel, 0, (object.facesV.size()/3));
	queue.finish();
	queue.enqueueReadBuffer(b_faces, CL_TRUE, 0, (object.facesV.size()/3)*sizeof(cl_uint4), &faces[0]);
#else
		for (cl_uint i = 0; i < object.facesV.size(); i += 3)
		{
			faces.push_back({object.facesV[i + 0],
							 object.facesV[i + 1],
							 object.facesV[i + 2],
							 cl_uint(offset + faces.size())});
		}
#endif

#if 0
	for(size_t i = 0; i < object.facesV.size()/3; ++i){
		std::cout << faces[i].s0 << ", "
			<< faces[i].s1 << ", "
			<< faces[i].s2 << ", "
			<< faces[i].s3 << ", "
		 	<< std::endl;
	}
#endif
	}

	void ModelLoader::getFaceNormalsOfObject(
		object3D object, std::vector<cl_uint4> &faceNormals, cl_int offset)
	{
#if 0
	cl::Kernel kernel = cl::Kernel(bvh_program, "getFaceNormalsOfObject");

	cl::Buffer b_facesVN = cl::Buffer(
		context, 
		CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, 
		object.facesVN.size()*sizeof(uint),
		&object.facesVN[0]
	);
	kernel.setArg(0, b_facesVN);

	faceNormals = std::vector<cl_uint4>(object.facesVN.size()/3);
	cl::Buffer b_normals = cl::Buffer(
		context, 
		CL_MEM_WRITE_ONLY, 
		(object.facesVN.size()/3)*sizeof(cl_uint4)
	);
	kernel.setArg(1, b_normals);
	kernel.setArg(2, offset);

	// launch the kernel
	queue.enqueueNDRangeKernel(kernel, 0, (object.facesVN.size()/3));
	queue.finish();
	queue.enqueueReadBuffer(b_normals, CL_TRUE, 0, (object.facesVN.size()/3)*sizeof(cl_uint4), &faceNormals[0]);
#else
		for (cl_uint i = 0; i < object.facesVN.size(); i += 3)
		{
			faceNormals.push_back({object.facesVN[i + 0],
								   object.facesVN[i + 1],
								   object.facesVN[i + 2],
								   cl_uint(offset + faceNormals.size())});
		}
#endif
	}

	void ModelLoader::loadModel(std::string filepath, std::string filename)
	{
		// using std::vector;

		// char msg[256];
		// snprintf(msg, 256, "[ModelLoader] Importing model \"%s\" ...", filename.c_str());
		// std::cout << msg << std::endl;

		// mObjParser->load(filepath, filename);

		// vector<cl_uint> facesV = mObjParser->getFacesV();
		// vector<cl_uint> facesVN = mObjParser->getFacesVN();
		// vector<cl_float> vertices = mObjParser->getVertices();

		// std::cout << "[ModelLoader] ... Done." << std::endl;
	}

	bool ModelLoader::ImportFromFile(const std::string &filepath, std::unique_ptr<SceneData> &sceneData)
	{
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

		return true;
	}

	std::unique_ptr<SceneData> ModelLoader::ProcessData(const aiScene *scene)
	{
		std::unique_ptr<SceneData> ret = std::make_unique<SceneData>();

		bool repeat = true;

		std::vector<const aiNode *> nodeBuff;
		nodeBuff.push_back(scene->mRootNode);

		/* if (modelScene->mNumMeshes > 0)
   {
   for (unsigned int m=0;m<modelScene->mNumMeshes;m++)
   this->assimpGetMeshData(modelScene->mMeshes[m]);
   }*/

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
					ret->emplace_back(assimpGetMeshData(scene->mMeshes[b]));
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

		// if (mesh->HasTangentsAndBitangents())
		// {
		// 	for (unsigned int v = 0; v < mesh->mNumVertices; ++v)
		// 	{
		// 		res.second.push_back(mesh->mTangents[v].x);
		// 		res.second.push_back(mesh->mTangents[v].y);
		// 		res.second.push_back(mesh->mTangents[v].z);
		// 	}
		// }

		return res;
	}

} // namespace IO

#include <Model/model_loader.h>
#include <iostream>

extern cl::Context context;
extern cl::Device device;
extern cl::CommandQueue queue;
extern cl::Program bvh_program;

ModelLoader::ModelLoader() {
	mObjParser = new ObjParser();
}

ModelLoader::~ModelLoader() {
	delete mObjParser;
}

void ModelLoader::getFacesOfObject(
	object3D object, std::vector<cl_uint4>& faces, cl_int offset
) {
#if 1
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
	cl_uint a, b, c;

	for (cl_uint i = 0; i < object.facesV.size(); i += 3) {
		a = object.facesV[i + 0];
		b = object.facesV[i + 1];
		c = object.facesV[i + 2];

		cl_uint4 f = { a, b, c, offset + faces.size() };
		faces.push_back(f);
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
	object3D object, std::vector<cl_uint4>& faceNormals, cl_int offset
) {
#if 1
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
	cl_uint a, b, c;

	for (cl_uint i = 0; i < object.facesVN.size(); i += 3) {
		a = object.facesVN[i + 0];
		b = object.facesVN[i + 1];
		c = object.facesVN[i + 2];

		cl_uint4 fn = { a, b, c, offset + faceNormals->size() };
		faceNormals->push_back(fn);
	}
#endif
}

ObjParser* ModelLoader::getObjParser() {
	return mObjParser;
}

void ModelLoader::loadModel(std::string filepath, std::string filename) {
	using std::vector;
	
	char msg[256];
	snprintf(msg, 256, "[ModelLoader] Importing model \"%s\" ...", filename.c_str());
	std::cout << msg << std::endl;

	mObjParser->load(filepath, filename);

	vector<cl_uint> facesV = mObjParser->getFacesV();
	vector<cl_uint> facesVN = mObjParser->getFacesVN();
	vector<cl_float> vertices = mObjParser->getVertices();

	std::cout << "[ModelLoader] ... Done." << std::endl;
}
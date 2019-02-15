#include <Model/model_loader.h>
#include <iostream>

extern cl::Context context;
extern cl::Device device;
extern cl::CommandQueue queue;

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
	cl::Program bvh_program = cl::Program(context, utils::ReadFile("../kernels/bvh.cl").c_str());

	cl_int result = bvh_program.build({device}, ""); // "-cl-fast-relaxed-math"
	if (result)
		std::cout << "Error during compilation OpenCL code!!!\n (" << result << ")" << std::endl;
	if (result == CL_BUILD_PROGRAM_FAILURE)
		std::cerr << "couldn't load the program '" << "../kernels/bvh.cl" << "'\n";

	cl::Kernel bvh_kernel = cl::Kernel(bvh_program, "getFacesOfObject");

	cl::Buffer b_facesV = cl::Buffer(
		context, 
		CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, 
		object.facesV.size()*sizeof(uint),
		&object.facesV[0]
	);
	bvh_kernel.setArg(0, b_facesV);

	faces = std::vector<cl_uint4>(object.facesV.size()/3);
	cl::Buffer b_faces = cl::Buffer(
		context, 
		CL_MEM_WRITE_ONLY, 
		(object.facesV.size()/3)*sizeof(cl_uint4)
	);
	bvh_kernel.setArg(1, b_faces);
	bvh_kernel.setArg(2, offset);

	// launch the kernel
	// std::cout << queue.enqueueWriteBuffer(b_facesV, CL_TRUE, 0, object.facesV.size()*sizeof(uint),object.facesV.data());
	queue.enqueueNDRangeKernel(bvh_kernel, 0, (object.facesV.size()/3));
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
	object3D object, std::vector<cl_uint4>* faceNormals, cl_int offset
) {
	cl_uint a, b, c;

	for (cl_uint i = 0; i < object.facesVN.size(); i += 3) {
		a = object.facesVN[i + 0];
		b = object.facesVN[i + 1];
		c = object.facesVN[i + 2];

		cl_uint4 fn = { a, b, c, offset + faceNormals->size() };
		faceNormals->push_back(fn);
	}
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
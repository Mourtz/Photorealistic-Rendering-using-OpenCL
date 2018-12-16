#include <iostream>
#include <cstdlib>
#include <fstream>
#include <vector>
#include <string>

#include <rapidjson/document.h>
#include <rapidjson/istreamwrapper.h>

#include <GL/glew.h>
#define CL_VERSION_1_2
#define __CL_ENABLE_EXCEPTIONS
#include <CL/cl.hpp>

#if defined OS_WIN
	#define GLFW_EXPOSE_NATIVE_WIN32
	#define GLFW_EXPOSE_NATIVE_WGL
#elif defined OS_LNX
	#define GLFW_EXPOSE_NATIVE_X11
	#define GLFW_EXPOSE_NATIVE_GLX
#endif

#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

//-----------------------------------------------------------------

using std::vector;
using std::string;
using std::cout;
using std::cin;
using std::endl;

#include <CL/cl_help.h>
namespace clw = cl_help;

//-----------------------------------------------------------------

#include <BVH/bvh.h>
#include <GL/cl_gl_interop.h>
#include <Math/linear_algebra.h>
#include <Math/random.h>
#include <Camera/camera.h>
#include <Scene/scene.h>

#define __DEBUG__

const string models_directory = "../resources/models/";
const string kernel_filepath = "../kernels/main.cl";

// every pixel in the image has its own thread or "work item",
// so the total amount of work items equals the number of pixels
std::size_t global_work_size = window_width * window_height;
std::size_t local_work_size;

// OpenCL objects
clw::Buffer cl_output;
clw::Buffer cl_meshes;
clw::Buffer cl_camera;
clw::Buffer cl_accumbuffer;
clw::ImageGL cl_screen;
clw::ImageGL cl_env_map;
clw::ImageGL cl_noise_tex;
vector<clw::Memory> cl_screens;

cl_uint BVH_NUM_NODES(0);
clw::Buffer mBufBVH;
clw::Buffer mBufBVHFaces;
clw::Buffer mBufFacesV;
clw::Buffer mBufFacesN;
clw::Buffer mBufVertices;
clw::Buffer mBufNormals;
clw::Buffer mBufMaterial;

// current frame number
cl_uint framenumber = 0;

// cpu_camera
Camera* hostRendercam = nullptr;

host_scene* scene = nullptr;

//-----------------------------------------------------------------

std::size_t initOpenCLBuffers_BVH(BVH* bvh, ModelLoader* ml, vector<cl_uint> faces) {
	vector<BVHNode*> bvhNodes = bvh->getNodes();
	vector<bvhNode_cl> bvhNodesCL;

	vector<cl_uint> facesVN = ml->getObjParser()->getFacesVN();
	vector<cl_int> facesMtl = ml->getObjParser()->getFacesMtl();
	vector<cl_uint4> facesV;
	vector<cl_uint4> facesN;

	bool skipNext = false;

	for (cl_uint i = 0; i < bvhNodes.size(); i++) {
		BVHNode* node = bvhNodes[i];

		if (skipNext) {
			skipNext = node->skipNextLeft;
			continue;
		}

		cl_float4 bbMin = { node->bbMin[0], node->bbMin[1], node->bbMin[2], 0.0f };
		cl_float4 bbMax = { node->bbMax[0], node->bbMax[1], node->bbMax[2], 0.0f };

		bvhNode_cl sn;
		sn.bbMin = bbMin;
		sn.bbMax = bbMax;

		vector<Tri> facesVec = node->faces;
		cl_uint fvecLen = facesVec.size();
		sn.bbMin.s[3] = (fvecLen > 0) ? (cl_float)facesV.size() + 0 : -1.0f;
		sn.bbMax.s[3] = (fvecLen > 1) ? (cl_float)facesV.size() + 1 : -1.0f;

		// Set the flag to skip the next left child node.
		if (fvecLen == 0 && node->skipNextLeft) {
			skipNext = true;
		}

		// No parent means it's the root node.
		// Otherwise it is some other node, including leaves.
		// Also for leaf nodes the next node to visit is given by the position in memory.
		if (node->parent != NULL && fvecLen == 0) {
			bool isLeftNode = (node->parent->leftChild == node);

			if (!isLeftNode) {
				if (node->parent->parent != NULL) {
					BVHNode* dummy = new BVHNode();
					dummy->parent = node->parent;

					// As long as we are on the right side of a (sub)tree,
					// skip parents until we either are at the root or
					// our parent has a true sibling again.
					while (dummy->parent->parent->rightChild == dummy->parent) {
						dummy->parent = dummy->parent->parent;

						if (dummy->parent->parent == NULL) {
							break;
						}
					}

					// Reached a parent with a true sibling.
					if (dummy->parent->parent != NULL) {
						sn.bbMax.s[3] = dummy->parent->parent->rightChild->id - dummy->parent->parent->rightChild->numSkipsToHere;
					}
				}
			}
			// Node on the left, go to the right sibling.
			else {
				sn.bbMax.s[3] = node->parent->rightChild->id - node->parent->rightChild->numSkipsToHere;
			}
		}

		bvhNodesCL.push_back(sn);

		// Faces
		for (int j = 0; j < fvecLen; j++) {
			Tri tri = facesVec[j];
			cl_uint4 fv;
			cl_uint4 fn;

			fv.s[0] = faces[tri.face.s[3] * 3];
			fv.s[1] = faces[tri.face.s[3] * 3 + 1];
			fv.s[2] = faces[tri.face.s[3] * 3 + 2];
			// Material of face @ToDo
			//fv.w = facesMtl[tri.face.w];

			fn.s[0] = facesVN[tri.normals.s[3] * 3];
			fn.s[1] = facesVN[tri.normals.s[3] * 3 + 1];
			fn.s[2] = facesVN[tri.normals.s[3] * 3 + 2];
			fn.s[3] = 0;

			facesV.push_back(fv);
			facesN.push_back(fn);
		}
	}

	std::size_t bytesBVH = sizeof(bvhNode_cl) * bvhNodesCL.size();
	mBufBVH = clw::createBuffer(bvhNodesCL, bytesBVH);

	BVH_NUM_NODES = bvhNodesCL.size();
	//mCL->setReplacement(string("#BVH_NUM_NODES#"), string(msg));

	char msg[16];
	snprintf(msg, 16, "%lu", BVH_NUM_NODES);
	cout << "BVH_NODES: " << msg << endl;

	std::size_t bytesFV = sizeof(cl_uint4) * facesV.size();
	mBufFacesV = clw::createBuffer(facesV, bytesFV);

	std::size_t bytesFN = sizeof(cl_uint4) * facesN.size();
	mBufFacesN = clw::createBuffer(facesN, bytesFN);

	return bytesBVH + bytesFV + bytesFN;
}

std::size_t initOpenCLBuffers_Faces(
	ModelLoader* ml, vector<cl_float> vertices, vector<cl_uint> faces, vector<cl_float> normals
) {
	vector<cl_float4> vertices4;
	vector<cl_float4> normals4;

	for (int i = 0; i < vertices.size(); i += 3) {
		cl_float4 v = { vertices[i], vertices[i + 1], vertices[i + 2], 0.0f };
		vertices4.push_back(v);
	}

	for (int i = 0; i < normals.size(); i += 3) {
		cl_float4 n = { normals[i], normals[i + 1], normals[i + 2], 0.0f };
		normals4.push_back(n);
	}

	std::size_t bytesV = sizeof(cl_float4) * vertices4.size();
	std::size_t bytesN = sizeof(cl_float4) * normals4.size();

	mBufVertices = clw::Buffer(context, CL_MEM_READ_ONLY, bytesV);
	queue.enqueueWriteBuffer(mBufVertices, CL_TRUE, 0, bytesV, vertices4.data());
	//mBufVertices = mCL->createBuffer(vertices4, bytesV);

	mBufNormals = clw::Buffer(context, CL_MEM_READ_ONLY, bytesN);
	queue.enqueueWriteBuffer(mBufNormals, CL_TRUE, 0, bytesN, normals4.data());
	//mBufNormals = mCL->createBuffer(normals4, bytesN);

	return bytesV + bytesN;
}

void initOpenCLBuffers(
	vector<cl_float> vertices, vector<cl_uint> faces, vector<cl_float> normals,
	ModelLoader* ml, BVH* accelStruc
) {
	double timerStart;
	double timerEnd;
	double timeDiff;
	std::size_t bytes;
	float bytesFloat;
	string unit;

	const int MSG_LENGTH = 128;
	char msg[MSG_LENGTH];

	cout << "Initializing OpenCL buffers ..." << endl;
	
	// Buffer: Faces
	timerStart = glfwGetTime();
	bytes = initOpenCLBuffers_Faces(ml, vertices, faces, normals);
	timerEnd = glfwGetTime();
	timeDiff = (timerEnd - timerStart);
	utils::formatBytes(bytes, &bytesFloat, &unit);
	snprintf( msg, MSG_LENGTH, "[PathTracer] Created faces buffer in %g ms -- %.2f %s.", timeDiff, bytesFloat, unit.c_str() );
	cout << msg << endl;

	// Buffer: Acceleration Structure
	timerStart = glfwGetTime();
	bytes = initOpenCLBuffers_BVH(accelStruc, ml, faces);
	timerEnd = glfwGetTime();
	timeDiff = (timerEnd - timerStart);
	utils::formatBytes(bytes, &bytesFloat, &unit);
	snprintf(msg, MSG_LENGTH, "[PathTracer] Created BVH buffer in %g ms -- %.2f %s.", timeDiff, bytesFloat, unit.c_str());
	cout << msg << endl;
}

void initOpenCL()
{
	// Get all available OpenCL platforms (e.g. AMD OpenCL, Nvidia CUDA, Intel OpenCL)
	vector<clw::Platform> platforms;
	clw::Platform::get(&platforms);
	cout << "Available OpenCL platforms : " << endl << endl;
	for (int i = 0; i < platforms.size(); i++)
		cout << "\t" << i + 1 << ": " << platforms[i].getInfo<CL_PLATFORM_NAME>() << endl;

	// Pick one platform
	clw::Platform platform;
	clw::pickPlatform(platform, platforms);
	cout << "\nUsing OpenCL platform: \t" << platform.getInfo<CL_PLATFORM_NAME>() << endl;

	// Get available OpenCL devices on platform
	vector<clw::Device> devices;
	platform.getDevices(CL_DEVICE_TYPE_ALL, &devices);

	cout << "Available OpenCL devices on this platform: " << endl << endl;
	for (int i = 0; i < devices.size(); i++){
		cout << "\t" << i + 1 << ": " << devices[i].getInfo<CL_DEVICE_NAME>() << endl;
		cout << "\t\tMax compute units: " << devices[i].getInfo<CL_DEVICE_MAX_COMPUTE_UNITS>() << endl;
		cout << "\t\tMax work group size: " << devices[i].getInfo<CL_DEVICE_MAX_WORK_GROUP_SIZE>() << endl << endl;
	}

	// Pick one device
	//Device device;
	clw::pickDevice(device, devices);
	cout << "\nUsing OpenCL device: \t" << device.getInfo<CL_DEVICE_NAME>() << endl;
	cout << "\t\t\tMax compute units: " << device.getInfo<CL_DEVICE_MAX_COMPUTE_UNITS>() << endl;
	cout << "\t\t\tMax work group size: " << device.getInfo<CL_DEVICE_MAX_WORK_GROUP_SIZE>() << endl;

	std::vector<cl_context_properties> properties;
#if defined OS_WIN
    properties =
	{
		CL_GL_CONTEXT_KHR, (cl_context_properties)glfwGetWGLContext(window),
		CL_WGL_HDC_KHR, (cl_context_properties)GetDC(glfwGetWin32Window(window)),
		CL_CONTEXT_PLATFORM, (cl_context_properties)platform(),
		0
	};
#elif defined OS_LNX
    properties =
	{
		CL_GL_CONTEXT_KHR, (cl_context_properties)glfwGetGLXContext(window),
		CL_GLX_DISPLAY_KHR, (cl_context_properties)glfwGetX11Display(),
		CL_CONTEXT_PLATFORM, (cl_context_properties)platform(),
		0
	};
#else
	std::cout << "there's only support for Windows and Linux at the moment" << std::endl; 
	exit(1);
#endif

	// Create an OpenCL context
	context = clw::Context(device, properties.data());

	// Create a command queue
	queue = clw::CommandQueue(context, device);

	// Create an OpenCL program with source
	program = clw::Program(context, clw::loadKernelFile(kernel_filepath, scene).c_str());

	// Build the program for the selected device
	cl_int result = program.build({ device }); // "-cl-fast-relaxed-math"
	if (result) cout << "Error during compilation OpenCL code!!!\n (" << result << ")" << endl;
	if (result == CL_BUILD_PROGRAM_FAILURE) clw::printErrorLog(program, device);
}

//---------------------------------------------------------------------------------------

void initCLKernel(){

	// Create a kernel (entry point in the OpenCL source program)
	kernel = clw::Kernel(program, "render_kernel");

	// specify OpenCL kernel arguments
	kernel.setArg(0, cl_meshes);
	kernel.setArg(1, window_width);
	kernel.setArg(2, window_height);
	kernel.setArg(3, scene->object_count);
	kernel.setArg(4, framenumber);
	kernel.setArg(5, cl_camera);
	kernel.setArg(6, rand());
	kernel.setArg(7, rand());
	kernel.setArg(8, cl_accumbuffer);
	kernel.setArg(9, cl_screen);

	kernel.setArg(10, BVH_NUM_NODES);
	kernel.setArg(11, mBufBVH);
	kernel.setArg(12, mBufFacesV);
	kernel.setArg(13, mBufFacesN);
	kernel.setArg(14, mBufVertices);
	kernel.setArg(15, mBufNormals);
	kernel.setArg(16, mBufMaterial);

	kernel.setArg(17, cl_env_map);
	kernel.setArg(18, cl_noise_tex);
}

//---------------------------------------------------------------------------------------

#ifdef __DEBUG__
double acc_time(0);
#endif

void runKernel(){
	//Make sure OpenGL is done using the VBOs
	glFinish();

	//this passes in the vector of VBO buffer objects
	queue.enqueueAcquireGLObjects(&cl_screens);
	queue.finish();

#ifdef __DEBUG__
	double tStart = glfwGetTime();
#endif
	// launch the kernel
	queue.enqueueNDRangeKernel(kernel, NULL, global_work_size, local_work_size); // local_work_size
	queue.finish();
#ifdef __DEBUG__
#if 1
	acc_time += (glfwGetTime() - tStart);
	// display avg render time per frame
	cout << "\rRender Time: " << (acc_time / framenumber) << "s  " << std::flush;
#else
	// display render time per frame
	cout << "\rRender Time: " << (glfwGetTime() - tStart) << "s  " << std::flush;
#endif
#endif

	//Release the VBOs so OpenGL can play with them
	queue.enqueueReleaseGLObjects(&cl_screens);
	queue.finish();
}

//---------------------------------------------------------------------------------------

void render(){

	if (buffer_reset){
#ifdef __DEBUG__
		acc_time = 0;
#endif
		float arg = 0;
		queue.enqueueFillBuffer(cl_accumbuffer, arg, 0, window_width * window_height * sizeof(cl_float4));
		framenumber = 0;
	}
	buffer_reset = false;
	++framenumber;

	// build a new camera for each frame on the CPU
	interactiveCamera->buildRenderCamera(hostRendercam);
	// copy the host camera to a OpenCL camera
	queue.enqueueWriteBuffer(cl_camera, CL_TRUE, 0, sizeof(Camera), hostRendercam);
	queue.finish();

	kernel.setArg(4, framenumber);
	kernel.setArg(5, cl_camera);
	kernel.setArg(6, rand());
	kernel.setArg(7, rand());

	runKernel();

	drawGL();
}

//---------------------------------------------------------------------------------------

// initialise camera on the CPU
void initCamera()
{
	delete interactiveCamera;
	interactiveCamera = new InteractiveCamera();

	interactiveCamera->setResolution(window_width, window_height);
	interactiveCamera->setFOVX(45.0f);
}

//---------------------------------------------------------------------------------------

int main(int argc, char** argv){

	// debug statements
#ifdef __DEBUG__
	cout << "size of int: " << sizeof(int) << std::endl;
	cout << "size of cl_int: " << sizeof(cl_int) << std::endl;
	cout << "size of float: " << sizeof(float) << std::endl;
	cout << "size of cl_float: " << sizeof(cl_float) << std::endl;
	cout << "size of cl_float3: " << sizeof(cl_float3) << std::endl;
	cout << "size of cl_float4: " << sizeof(cl_float4) << std::endl;
	cout << "size of cl_float8: " << sizeof(cl_float8) << std::endl;
	cout << "size of cl_float16: " << sizeof(cl_float16) << std::endl;
	cout << "size of Mesh: " << sizeof(Mesh) << std::endl;
	cout << "size of Camera: " << sizeof(Camera) << std::endl;
#endif

	// parse command line arguments
	for (int i = 0; i < argc; ++i) {
		string arg = argv[i];

		if (arg == "-scene") { // scene to render
			scene_filepath = argv[++i];
		} else if (arg == "-width") { // window width
			window_width = atoi(argv[++i]);
		} else if (arg == "-height") { // window height
			window_height = atoi(argv[++i]);
		} else if (arg == "-hdr") {// hdr enviroment map
			env_map_filepath = argv[++i];
		} else if (arg == "-alpha") {// alpha channel
			ALPHA_TESTING = true;
		} else if (arg == "-encoder") {// encoder { 0: ".png", 1: ".hdr" } 
			encoder = atoi(argv[++i]);
		}
	}

	// initialise OpenGL (GLEW and GLUT window + callback functions)
	initGL();

	// initialise scene
	scene = new host_scene();
	scene->load();

	cl_int err;

	// initialise OpenCL
	initOpenCL();

#ifdef __DEBUG__
	std::cout << "device specifications:" << std::endl;
	if (!device.getInfo<CL_DEVICE_IMAGE_SUPPORT>(&err)) {
		OPENCL_EXPECTED_ERROR("Images are not supported on this device!");
	}

	cout << "> max image2D size (" << device.getInfo<CL_DEVICE_IMAGE2D_MAX_WIDTH>(&err) << "x" << device.getInfo<CL_DEVICE_IMAGE2D_MAX_HEIGHT>(&err) << ")" << std::endl;
#endif

	std::cout << "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-" << std::endl;
	
	glfwShowWindow(window);

	//make sure OpenGL is finished before we proceed
	glFinish();

	if (scene->BUILD_BVH) {
		mBufMaterial = clw::Buffer(context, CL_MEM_READ_ONLY, sizeof(Material));
		queue.enqueueWriteBuffer(mBufMaterial, CL_TRUE, 0, sizeof(Material), scene->obj_mat);

		ModelLoader* ml = new ModelLoader();
		ml->loadModel(models_directory, scene->obj_path);

		ObjParser* op = ml->getObjParser();

		vector<cl_uint> mFaces = op->getFacesV();
		vector<cl_float> mNormals = op->getNormals();
		vector<cl_float> mVertices = op->getVertices();

		BVH* accelStruct = new BVH(op->getObjects(), mVertices, mNormals);

		initOpenCLBuffers(mVertices, mFaces, mNormals, ml, accelStruct);

		delete ml;
		delete accelStruct;
	}

	//
	cl_meshes = clw::createBuffer(scene->cpu_meshes, scene->object_count.s[7] * sizeof(Mesh));

	// initialise an interactive camera on the CPU side
	initCamera();

	// create a CPU camera
	hostRendercam = new Camera();
	// camera's CL memory buffer
	cl_camera = clw::Buffer(context, CL_MEM_READ_ONLY, sizeof(Camera));
	queue.enqueueWriteBuffer(cl_camera, CL_TRUE, 0, sizeof(Camera), hostRendercam);

#if 0
	Texture* cubemap = loadHDR(env_map_filepath.c_str());
	cl_env_map = cl::Image2D(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, cl::ImageFormat( CL_RGBA, CL_HALF_FLOAT ), cubemap->width, cubemap->height, 0, cubemap->data, &err);
#else
	cl_env_map = clw::ImageGL(context, CL_MEM_READ_ONLY, GL_TEXTURE_2D, 0, tex1, &err);
	cl_screens.push_back(cl_env_map);
#endif
	if (err) cout << cl_help::getOpenCLErrorCodeStr(err) << std::endl;

	// noise texture
	cl_noise_tex = clw::ImageGL(context, CL_MEM_READ_ONLY, GL_TEXTURE_2D, 0, tex2, &err);
	cl_screens.push_back(cl_noise_tex);
	if (err) cout << cl_help::getOpenCLErrorCodeStr(err) << std::endl;

	// radiance
	cl_screen = clw::ImageGL(context, CL_MEM_WRITE_ONLY, GL_TEXTURE_2D, 0, tex0, &err);
	cl_screens.push_back(cl_screen);
	if (err) cout << cl_help::getOpenCLErrorCodeStr(err) << std::endl;

	// reserve memory buffer on OpenCL device to hold image buffer for accumulated samples
	cl_accumbuffer = clw::Buffer(context, CL_MEM_WRITE_ONLY, window_width * window_height * sizeof(cl_float4));

	// intitialise the kernel
	initCLKernel();

	// every pixel in the image has its own thread or "work item",
	// so the total amount of work items equals the number of pixels
	local_work_size = kernel.getWorkGroupInfo<CL_KERNEL_WORK_GROUP_SIZE>(device);

	// Ensure the global work size is a multiple of local work size
	if (global_work_size % local_work_size != 0)
		global_work_size = (global_work_size / local_work_size + 1) * local_work_size;

	// render loop
	while (!glfwWindowShouldClose(window)) {
		// poll for events
		glfwPollEvents();
		// render call
		render();
		// swap front and back buffers
		glfwSwapBuffers(window);

		if (render_to_file) {
			saveImage();
			render_to_file = false;
		}
	}

	glfwDestroyWindow(window);
	glfwTerminate();
	return 0;
}

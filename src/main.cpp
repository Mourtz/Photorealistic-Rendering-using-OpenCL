/**
 *	@author Alex Mourtziapis - 2019 
 */

#define __DEBUG__
#define NOMINMAX

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

#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

//----------------------------------------------

constexpr char *models_directory = "../resources/models/";
constexpr char *kernel_filepath = "../kernels/main.cl";

constexpr std::size_t RayI_size = 16 * 7;

//----------------------------------------------

#include <Camera/camera.h>
#include <Scene/scene.h>
#include <GL/cl_gl_interop.h>
#include <BVH/bvh.h>

#include <CL/cl_help.h>
#if 1
namespace clw = cl_help;
#else
#define clw cl_help
#endif

// window width
int window_width = 1280;
// window height
int window_height = 720;
// enviroment map filepath
std::string env_map_filepath = "";
// encoder
unsigned char encoder = 0;

cl::Device device;
cl::Context context;
cl::CommandQueue queue;
cl::Kernel kernel;
cl::Program program;
// cl::Program bvh_program;
cl::Buffer cl_output;
cl::Buffer cl_meshes;
cl::Buffer cl_camera;
cl::ImageGL cl_screen;
cl::ImageGL cl_env_map;
//  clw::ImageGL cl_noise_tex;
std::vector<cl::Memory> cl_screens;
cl::Buffer mBufBVH;
cl::Buffer mBufFacesV;
cl::Buffer mBufVertices;
cl::Buffer mBufNormals;
cl::Buffer mBufMaterial;
cl::Buffer cl_flattenI;

std::size_t global_work_size;
std::size_t local_work_size;
cl_uint BVH_NUM_NODES = 0;
cl_uint framenumber = 0;
Camera *hostRendercam = nullptr;
InteractiveCamera *interactiveCamera = nullptr;
host_scene *scene = nullptr;
std::string scene_filepath = "../scenes/cornell.json";
bool ALPHA_TESTING = false;

//----------------------------------------------

using namespace IO;

std::size_t
initOpenCLBuffers_BVH(const std::unique_ptr<BVH>& bvh, const std::vector<cl_uint>& faces)
{
	const std::vector<BVHNode *> bvhNodes = bvh->getNodes();
	std::vector<bvhNode_cl> bvhNodesCL;

	std::vector<cl_uint4> facesV;

	bool skipNext = false;

	for (const auto& node : bvhNodes)
	{
		if (skipNext)
		{
			skipNext = node->skipNextLeft;
			continue;
		}

		cl_float4 bbMin = {node->bbMin[0], node->bbMin[1], node->bbMin[2], 0.0f};
		cl_float4 bbMax = {node->bbMax[0], node->bbMax[1], node->bbMax[2], 0.0f};

		bvhNode_cl sn;
		sn.bbMin = bbMin;
		sn.bbMax = bbMax;

		std::vector<Tri> facesVec = node->faces;
		std::size_t fvecLen = facesVec.size();
		sn.bbMin.s[3] = (fvecLen > 0) ? (cl_float)facesV.size() + 0 : -1.0f;
		sn.bbMax.s[3] = (fvecLen > 1) ? (cl_float)facesV.size() + 1 : -1.0f;

		// Set the flag to skip the next left child node.
		if (fvecLen == 0 && node->skipNextLeft)
		{
			skipNext = true;
		}

		// No parent means it's the root node.
		// Otherwise it is some other node, including leaves.
		// Also for leaf nodes the next node to visit is given by the position in memory.
		if (node->parent != NULL && fvecLen == 0)
		{
			bool isLeftNode = (node->parent->leftChild == node);

			if (!isLeftNode)
			{
				if (node->parent->parent != NULL)
				{
					BVHNode *dummy = new BVHNode();
					dummy->parent = node->parent;

					// As long as we are on the right side of a (sub)tree,
					// skip parents until we either are at the root or
					// our parent has a true sibling again.
					while (dummy->parent->parent->rightChild == dummy->parent)
					{
						dummy->parent = dummy->parent->parent;

						if (dummy->parent->parent == NULL)
						{
							break;
						}
					}

					// Reached a parent with a true sibling.
					if (dummy->parent->parent != NULL)
					{
						sn.bbMax.s[3] = dummy->parent->parent->rightChild->id - dummy->parent->parent->rightChild->numSkipsToHere;
					}
				}
			}
			// Node on the left, go to the right sibling.
			else
			{
				sn.bbMax.s[3] = node->parent->rightChild->id - node->parent->rightChild->numSkipsToHere;
			}
		}

		bvhNodesCL.emplace_back(sn);

		// Faces
		for (std::size_t j = 0; j < fvecLen; ++j)
		{
			facesV.emplace_back(facesVec[j].face);
		}
	}

	std::size_t bytesBVH = sizeof(bvhNode_cl) * bvhNodesCL.size();
	mBufBVH = clw::buffer::create(bvhNodesCL, bytesBVH);

	BVH_NUM_NODES = bvhNodesCL.size();
	//mCL->setReplacement(string("#BVH_NUM_NODES#"), string(msg));

	char msg[16];
	snprintf(msg, 16, "%lu", BVH_NUM_NODES);
	std::cout << "BVH_NODES: " << msg << std::endl;

	std::size_t bytesFV = sizeof(cl_uint4) * facesV.size();
	mBufFacesV = clw::buffer::create(facesV, bytesFV);

	return bytesBVH + bytesFV;
}

std::size_t initOpenCLBuffers_Faces(
	const std::vector<cl_float>& vertices, const std::vector<cl_uint>& faces, const std::vector<cl_float>& normals)
{
	std::vector<cl_float4> vertices4;
	std::vector<cl_float4> normals4;

	for (std::size_t i = 0; i < vertices.size(); i += 3)
	{
		cl_float4 v = {vertices[i], vertices[i + 1], vertices[i + 2], 0.0f};
		vertices4.push_back(v);
	}

	for (std::size_t i = 0; i < normals.size(); i += 3)
	{
		cl_float4 n = {normals[i], normals[i + 1], normals[i + 2], 0.0f};
		normals4.push_back(n);
	}

	std::size_t bytesV = sizeof(cl_float4) * vertices4.size();
	std::size_t bytesN = sizeof(cl_float4) * normals4.size();

	mBufVertices = cl::Buffer(context, CL_MEM_READ_ONLY, bytesV);
	queue.enqueueWriteBuffer(mBufVertices, CL_TRUE, 0, bytesV, vertices4.data());
	//mBufVertices = mCL->createBuffer(vertices4, bytesV);

	mBufNormals = cl::Buffer(context, CL_MEM_READ_ONLY, bytesN);
	queue.enqueueWriteBuffer(mBufNormals, CL_TRUE, 0, bytesN, normals4.data());
	//mBufNormals = mCL->createBuffer(normals4, bytesN);

	return bytesV + bytesN;
}

void initOpenCLBuffers(
	const std::unique_ptr<SceneData>& data,
	const std::unique_ptr<BVH>& accelStruc)
{
	const std::vector<unsigned int>& faces = getIndices(data);
	const std::vector<float>& vertices = getPositions(data);
	const std::vector<float>& normals = getNormals(data);

	double timerStart;
	double timerEnd;
	double timeDiff;
	std::size_t bytes;
	float bytesFloat;
	std::string unit;

	const int MSG_LENGTH = 128;
	char msg[MSG_LENGTH];

	std::cout << "Initializing OpenCL buffers ..." << std::endl;

	// Buffer: Faces
	timerStart = glfwGetTime();
	bytes = initOpenCLBuffers_Faces(vertices, faces, normals);
	timerEnd = glfwGetTime();
	timeDiff = (timerEnd - timerStart);
	utils::formatBytes(bytes, &bytesFloat, &unit);
	snprintf(msg, MSG_LENGTH, "[PathTracer] Created faces buffer in %g ms -- %.2f %s.", timeDiff, bytesFloat, unit.c_str());
	std::cout << msg << std::endl;

	// Buffer: Acceleration Structure
	timerStart = glfwGetTime();
	bytes = initOpenCLBuffers_BVH(accelStruc, faces);
	timerEnd = glfwGetTime();
	timeDiff = (timerEnd - timerStart);
	utils::formatBytes(bytes, &bytesFloat, &unit);
	snprintf(msg, MSG_LENGTH, "[PathTracer] Created BVH buffer in %g ms -- %.2f %s.", timeDiff, bytesFloat, unit.c_str());
	std::cout << msg << std::endl;
}

void initOpenCL()
{
	// Get all available OpenCL platforms (e.g. AMD OpenCL, Nvidia CUDA, Intel OpenCL)
	std::vector<cl::Platform> platforms;
	cl::Platform::get(&platforms);
	std::cout << "Available OpenCL platforms : " << std::endl
			  << std::endl;
	for (std::size_t i = 0; i < platforms.size(); i++)
		std::cout << "\t" << i + 1 << ": " << platforms[i].getInfo<CL_PLATFORM_NAME>() << std::endl;

	// Pick one platform
	cl::Platform platform;
	clw::platform::select(platform, platforms);
	std::cout << "\nUsing OpenCL platform: \t" << platform.getInfo<CL_PLATFORM_NAME>() << std::endl;

	// Get available OpenCL devices on platform
	std::vector<cl::Device> devices;
	platform.getDevices(CL_DEVICE_TYPE_ALL, &devices);

	std::cout << "Available OpenCL devices on this platform: " << std::endl
			  << std::endl;
	for (std::size_t i = 0; i < devices.size(); i++)
	{
		std::cout << "\t" << i + 1 << ": " << devices[i].getInfo<CL_DEVICE_NAME>() << std::endl;
		std::cout << "\t\tMax compute units: " << devices[i].getInfo<CL_DEVICE_MAX_COMPUTE_UNITS>() << std::endl;
		std::cout << "\t\tMax work group size: " << devices[i].getInfo<CL_DEVICE_MAX_WORK_GROUP_SIZE>() << std::endl
				  << std::endl;
	}

	// Pick one device
	//Device device;
	clw::device::select(device, devices);
	std::cout << "\nUsing OpenCL device: \t" << device.getInfo<CL_DEVICE_NAME>() << std::endl;
	std::cout << "\t\t\tMax compute units: " << device.getInfo<CL_DEVICE_MAX_COMPUTE_UNITS>() << std::endl;
	std::cout << "\t\t\tMax work group size: " << device.getInfo<CL_DEVICE_MAX_WORK_GROUP_SIZE>() << std::endl;

	std::vector<cl_context_properties> properties;
#if defined OS_WIN
	properties =
		{
			CL_GL_CONTEXT_KHR, (cl_context_properties)glfwGetWGLContext(window),
			CL_WGL_HDC_KHR, (cl_context_properties)GetDC(glfwGetWin32Window(window)),
			CL_CONTEXT_PLATFORM, (cl_context_properties)platform(),
			0};
#elif defined OS_LNX
	properties =
		{
			CL_GL_CONTEXT_KHR, (cl_context_properties)glfwGetGLXContext(window),
			CL_GLX_DISPLAY_KHR, (cl_context_properties)glfwGetX11Display(),
			CL_CONTEXT_PLATFORM, (cl_context_properties)platform(),
			0};
#else
	std::cout << "there's only support for Windows and Linux at the moment" << std::endl;
	exit(1);
#endif

	// Create an OpenCL context
	context = cl::Context(device, properties.data());

	// Create a command queue
	queue = cl::CommandQueue(context, device);

	{
		// Create an OpenCL program with source
		program = cl::Program(context, clw::kernel::parse(kernel_filepath, scene).c_str());

		// Build the program for the selected device
		cl_int result = program.build({device}); // "-cl-fast-relaxed-math"
		if (result)
			std::cout << "Error during compilation OpenCL code!!!\n (" << result << ")" << std::endl;
		if (result == CL_BUILD_PROGRAM_FAILURE)
			clw::err::printErrorLog(program, device);
	}

/*
	{
		bvh_program = cl::Program(context, utils::ReadFile("../kernels/bvh.cl").c_str());

		cl_int result = bvh_program.build({device}); // "-cl-fast-relaxed-math"
		if (result)
			std::cout << "Error during compilation OpenCL code!!!\n (" << result << ")" << std::endl;
		if (result == CL_BUILD_PROGRAM_FAILURE)
			std::cerr << "couldn't load the program '" << "../kernels/bvh.cl" << "'\n";
	}
*/
}

//---------------------------------------------------------------------------------------

void initCLKernel()
{

	// Create a kernel (entry point in the OpenCL source program)
	kernel = cl::Kernel(program, "render_kernel");

	// specify OpenCL kernel arguments
	kernel.setArg(0, cl_meshes);
	kernel.setArg(1, window_width);
	kernel.setArg(2, window_height);
	kernel.setArg(3, scene->object_count);
	kernel.setArg(4, framenumber);
	kernel.setArg(5, cl_camera);
	kernel.setArg(6, rand());
	kernel.setArg(7, rand());
	kernel.setArg(8, cl_screen);

	kernel.setArg(9, BVH_NUM_NODES);
	kernel.setArg(10, mBufBVH);
	kernel.setArg(11, mBufFacesV);
	kernel.setArg(12, mBufVertices);
	kernel.setArg(13, mBufNormals);
	kernel.setArg(14, mBufMaterial);

	kernel.setArg(15, cl_env_map);
	// kernel.setArg(18, cl_noise_tex);
	kernel.setArg(16, cl_flattenI);
}

//---------------------------------------------------------------------------------------

#ifdef __DEBUG__
double acc_time(0);
#endif

void runKernel()
{
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
	std::cout << "\rRender Time: " << (acc_time / framenumber) << "s  " << std::flush;
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

void render()
{

	if (buffer_reset)
	{
#ifdef __DEBUG__
		acc_time = 0;
#endif
		queue.enqueueFillBuffer(cl_flattenI, 0, 0, window_width * window_height * RayI_size);
		framenumber = 0;
	}
	buffer_reset = false;

	// build a new camera for each frame on the CPU
	interactiveCamera->buildRenderCamera(hostRendercam);
	// copy the host camera to a OpenCL camera
	queue.enqueueWriteBuffer(cl_camera, CL_TRUE, 0, sizeof(Camera), hostRendercam);
	queue.finish();

	kernel.setArg(4, ++framenumber);
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

int main(int argc, char **argv)
{

	// debug statements
#ifdef __DEBUG__
	std::cout << "size of int: " << sizeof(int) << std::endl;
	std::cout << "size of cl_int: " << sizeof(cl_int) << std::endl;
	std::cout << "size of float: " << sizeof(float) << std::endl;
	std::cout << "size of cl_float: " << sizeof(cl_float) << std::endl;
	std::cout << "size of cl_float3: " << sizeof(cl_float3) << std::endl;
	std::cout << "size of cl_float4: " << sizeof(cl_float4) << std::endl;
	std::cout << "size of cl_float8: " << sizeof(cl_float8) << std::endl;
	std::cout << "size of cl_float16: " << sizeof(cl_float16) << std::endl;
	std::cout << "size of Mesh: " << sizeof(Mesh) << std::endl;
	std::cout << "size of Camera: " << sizeof(Camera) << std::endl;
#endif

	// parse command line arguments
	for (int i = 0; i < argc; ++i)
	{
		std::string arg = argv[i];

		if (arg == "-scene")
		{ // scene to render
			scene_filepath = argv[++i];
		}
		else if (arg == "-width")
		{ // window width
			window_width = atoi(argv[++i]);
		}
		else if (arg == "-height")
		{ // window height
			window_height = atoi(argv[++i]);
		}
		else if (arg == "-hdr")
		{ // hdr enviroment map
			env_map_filepath = argv[++i];
		}
		else if (arg == "-alpha")
		{ // alpha channel
			ALPHA_TESTING = true;
		}
		else if (arg == "-encoder")
		{ // encoder { 0: ".png", 1: ".hdr" }
			encoder = atoi(argv[++i]);
		}
	}
	global_work_size = window_width * window_height;

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
	if (!device.getInfo<CL_DEVICE_IMAGE_SUPPORT>(&err))
	{
		OPENCL_EXPECTED_ERROR("Images are not supported on this device!");
	}

	std::cout << "> max image2D size (" << device.getInfo<CL_DEVICE_IMAGE2D_MAX_WIDTH>(&err) << "x" << device.getInfo<CL_DEVICE_IMAGE2D_MAX_HEIGHT>(&err) << ")" << std::endl;
#endif

	std::cout << "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-" << std::endl;

	glfwShowWindow(window);

	//make sure OpenGL is finished before we proceed
	glFinish();

	if (scene->BUILD_BVH)
	{
		mBufMaterial = cl::Buffer(context, CL_MEM_READ_ONLY, sizeof(Material));
		queue.enqueueWriteBuffer(mBufMaterial, CL_TRUE, 0, sizeof(Material), scene->obj_mat);

		std::unique_ptr<ModelLoader> ml = std::make_unique<ModelLoader>();
		std::unique_ptr<SceneData> data;
		ml->ImportFromFile(std::string(models_directory + scene->obj_path), data);

		std::unique_ptr<BVH> accelStruct = std::make_unique<BVH>(data);

		initOpenCLBuffers(data, accelStruct);
	}

	//
	cl_meshes = clw::buffer::create(scene->cpu_meshes, scene->object_count.s[7] * sizeof(Mesh));

	// initialise an interactive camera on the CPU side
	initCamera();

	// create a CPU camera
	hostRendercam = new Camera();
	// camera's CL memory buffer
	cl_camera = cl::Buffer(context, CL_MEM_READ_ONLY, sizeof(Camera));
	queue.enqueueWriteBuffer(cl_camera, CL_TRUE, 0, sizeof(Camera), hostRendercam);

#if 0
	Texture* cubemap = loadHDR(env_map_filepath.c_str());
	cl_env_map = cl::Image2D(context, CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR, cl::ImageFormat( CL_RGBA, CL_HALF_FLOAT ), cubemap->width, cubemap->height, 0, cubemap->data, &err);
#else
	cl_env_map = cl::ImageGL(context, CL_MEM_READ_ONLY, GL_TEXTURE_2D, 0, tex1, &err);
	cl_screens.push_back(cl_env_map);
#endif
	if (err)
		std::cout << cl_help::err::getOpenCLErrorCodeStr(err) << std::endl;

	// noise texture
	// cl_noise_tex = clw::ImageGL(context, CL_MEM_READ_ONLY, GL_TEXTURE_2D, 0, tex2, &err);
	// cl_screens.push_back(cl_noise_tex);
	// if (err) cout << cl_help::getOpenCLErrorCodeStr(err) << std::endl;

	// radiance
	cl_screen = cl::ImageGL(context, CL_MEM_WRITE_ONLY, GL_TEXTURE_2D, 0, tex0, &err);
	cl_screens.push_back(cl_screen);
	if (err)
		std::cout << cl_help::err::getOpenCLErrorCodeStr(err) << std::endl;

	//
	cl_flattenI = cl::Buffer(context, CL_MEM_READ_WRITE, window_width * window_height * RayI_size);

	// intitialise the kernel
	initCLKernel();

	// every pixel in the image has its own thread or "work item",
	// so the total amount of work items equals the number of pixels
	local_work_size = kernel.getWorkGroupInfo<CL_KERNEL_WORK_GROUP_SIZE>(device);

	// Ensure the global work size is a multiple of local work size
	if (global_work_size % local_work_size != 0)
		global_work_size = (global_work_size / local_work_size + 1) * local_work_size;

	// render loop
	while (!glfwWindowShouldClose(window))
	{
		render();

		// swap front and back buffers
		glfwSwapBuffers(window);
		// poll for events
		glfwPollEvents();

		// render call
		if (render_to_file)
		{
			saveImage();
			render_to_file = false;
		}
	}

	glfwDestroyWindow(window);
	glfwTerminate();
	return 0;
}

/**
 *	@author Alex Mourtziapis - 2019 
 */

#define NOMINMAX

#include <iostream>
#include <cstdlib>
#include <fstream>
#include <vector>
#include <string>
#include <iomanip>
#include <cmath>

#include <rapidjson/document.h>
#include <rapidjson/istreamwrapper.h>

#include <GL/glew.h>
#define CL_HPP_ENABLE_EXCEPTIONS
#include <CL/opencl.hpp>

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

constexpr const char *models_directory = "../../resources/models/";
constexpr const char *kernel_filepath = "../../kernels/main.cl";

//----------------------------------------------

#include <Camera/camera.h>
#include <Scene/scene.h>
#include <GL/cl_gl_interop.h>
#include <Model/model_loader.h>
#include <BVH/bvh.h>
#include <UI/render_settings.h>
#include <UI/imgui_layer.h>

#include <CL/cl_help.h>
namespace clw = cl_help;

using namespace CL_RAYTRACER;

// window width
int window_width = 1920;
// window height
int window_height = 1080;
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
cl::Buffer mBufMeshMatSOA;
cl::Buffer mBufMeshPosSOA;
cl::Buffer mBufMeshJokerSOA;
cl::Buffer mBufMeshTypeSOA;
cl::Buffer cl_camera;
cl::ImageGL cl_screen;
cl::ImageGL cl_env_map;
//  clw::ImageGL cl_noise_tex;
std::vector<cl::Memory> cl_screens;
cl::Buffer mBufVertices;
cl::Buffer mBufNormals;
cl::Buffer soa_ray_org_t;     // float4: origin.xyz + t
cl::Buffer soa_ray_dir_time;  // float4: dir.xyz   + time
cl::Buffer soa_rlh_acc;       // float4: accumulation buffer (rgba)
cl::Buffer soa_rlh_mask_pdf;  // float4: throughput mask.xyz + last_bsdf_pdf
cl::Buffer soa_bounce;        // uint4:  diff|(spec<<16), trans|(scatters<<16), total, samples
cl::Buffer soa_flags;         // uint:   bit0=wasSpecular, bit1=reset
cl::Buffer mNewBufBVH;
cl::Buffer mNewBufIndices;
cl::Buffer cl_renderParams;
cl::Image2DArray cl_matTextures;
cl::Buffer cl_envMarginalCdf;
cl::Buffer cl_envConditionalCdf;
cl::Buffer cl_envPdf;
int g_envMapWidth  = 1;
int g_envMapHeight = 1;

RenderSettings g_settings;

std::size_t global_work_size;
std::size_t local_work_size;
cl_uint BVH_NUM_NODES = 0;
cl_uint framenumber = 0;
Camera *hostRendercam = nullptr;
InteractiveCamera *interactiveCamera = nullptr;
host_scene *scene = nullptr;
std::string scene_filepath = "../../scenes/cornell.json";
bool ALPHA_TESTING = false;
constexpr bool ENABLE_CL_PROFILING = false;

std::size_t initOpenCLBuffers_Faces(const std::shared_ptr<IO::ModelLoader>& ml, const BVH* bvh)
{
	std::unique_ptr<std::vector<cl_uint>> indices = bvh->GetPrimitiveIndices();
	std::vector<vec3> vertices4;
	std::vector<vec3> normals4;

	const auto& scene = ml->getFaces();
	for (const auto &mesh : scene->meshes)
	{
		for (const auto &face : mesh.faces)
		{
			vertices4.emplace_back(face.points[0].pos.x, face.points[0].pos.y, face.points[0].pos.z);
			vertices4.emplace_back(face.points[1].pos.x, face.points[1].pos.y, face.points[1].pos.z);
			vertices4.emplace_back(face.points[2].pos.x, face.points[2].pos.y, face.points[2].pos.z);

			normals4.emplace_back(face.points[0].nor.x, face.points[0].nor.y, face.points[0].nor.z);
			normals4.emplace_back(face.points[1].nor.x, face.points[1].nor.y, face.points[1].nor.z);
			normals4.emplace_back(face.points[2].nor.x, face.points[2].nor.y, face.points[2].nor.z);
		}
	}
	std::size_t bytesV = sizeof(vec3) * vertices4.size();
	std::size_t bytesN = sizeof(vec3) * normals4.size();
	std::size_t bytesIndices = sizeof(cl_uint) * indices->size();

	mBufVertices = clw::buffer::create(vertices4, bytesV);	
	mBufNormals = clw::buffer::create(normals4, bytesN);
	mNewBufIndices = clw::buffer::create(*indices, bytesIndices);

	return bytesV + bytesN + bytesIndices;
}

std::size_t initOpenCLBuffers_MeshSoA(const host_scene* hostScene)
{
	const std::size_t count = hostScene->object_count.s[7];
	const bool hasBvhFallbackMat = hostScene->BUILD_BVH;
	const std::size_t matsCount = count + (hasBvhFallbackMat ? 1 : 0);
	std::vector<Material> mats(matsCount);
	std::vector<cl_float4> pos(count);
	std::vector<cl_float16> joker(count);
	std::vector<cl_uchar> types(count);

	for (std::size_t i = 0; i < count; ++i)
	{
		const Mesh& m = hostScene->cpu_meshes[i];
		mats[i] = m.mat;
		pos[i] = {m.position.x, m.position.y, m.position.z, 0.0f};
		joker[i] = m.joker;
		types[i] = m.t;
	}

	// Reserve one trailing material slot for BVH triangle hits (mesh_id == -1).
	if (hasBvhFallbackMat)
		mats[count] = *hostScene->obj_mat;

	mBufMeshMatSOA = clw::buffer::create(mats, sizeof(Material) * matsCount);
	mBufMeshPosSOA = clw::buffer::create(pos, sizeof(cl_float4) * count);
	mBufMeshJokerSOA = clw::buffer::create(joker, sizeof(cl_float16) * count);
	mBufMeshTypeSOA = clw::buffer::create(types, sizeof(cl_uchar) * count);

	return sizeof(Material) * matsCount + sizeof(cl_float4) * count + sizeof(cl_float16) * count + sizeof(cl_uchar) * count;
}

static constexpr int TEX_SIZE      = 1024;
static constexpr int MAX_TEX_SLOTS = 16;

void buildMatTextureArray(const host_scene* s)
{
    const int nTex = std::min((int)s->texturePaths.size(), MAX_TEX_SLOTS);
    // Always allocate at least one slot so the Image2DArray is valid.
    const int arraySize = std::max(nTex, 1);

    // Flat RGBA8 buffer: arraySize × TEX_SIZE × TEX_SIZE × 4 bytes
    std::vector<cl_uchar> pixels(arraySize * TEX_SIZE * TEX_SIZE * 4, 128u);

    for (int i = 0; i < nTex; ++i) {
        Texture<unsigned char>* tex = loadPNG(s->texturePaths[i].c_str());
        if (!tex || !tex->data) {
            std::cerr << "[Textures] Failed to load: " << s->texturePaths[i] << std::endl;
            delete tex;
            continue;
        }

        const int sw = tex->width;
        const int sh = tex->height;
        const int nc = tex->nrComponents;

        for (int y = 0; y < TEX_SIZE; ++y) {
            int sy = (y * sh) / TEX_SIZE;
            for (int x = 0; x < TEX_SIZE; ++x) {
                int sx = (x * sw) / TEX_SIZE;
                const int srcIdx  = (sy * sw + sx) * nc;
                const int dstIdx  = (i * TEX_SIZE * TEX_SIZE + y * TEX_SIZE + x) * 4;
                pixels[dstIdx + 0] = (nc > 0) ? tex->data[srcIdx + 0] : 128u;
                pixels[dstIdx + 1] = (nc > 1) ? tex->data[srcIdx + 1] : 128u;
                pixels[dstIdx + 2] = (nc > 2) ? tex->data[srcIdx + 2] : 128u;
                pixels[dstIdx + 3] = (nc > 3) ? tex->data[srcIdx + 3] : 255u;
            }
        }
        stbi_image_free(tex->data);
        delete tex;
        std::cout << "[Textures] Loaded slot " << i << ": " << s->texturePaths[i] << std::endl;
    }

    cl_int err = CL_SUCCESS;
    cl::ImageFormat fmt(CL_RGBA, CL_UNORM_INT8);
    cl_matTextures = cl::Image2DArray(
        context,
        CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR,
        fmt,
        arraySize,  // array_size
        TEX_SIZE, TEX_SIZE,
        0, 0,       // row_pitch, slice_pitch (auto)
        pixels.data(),
        &err);
    if (err)
        std::cerr << "[Textures] Image2DArray creation error: "
                  << cl_help::err::getOpenCLErrorCodeStr(err) << std::endl;
    else
        std::cout << "[Textures] Material texture array: "
                  << arraySize << " slot(s) @ " << TEX_SIZE << "x" << TEX_SIZE << std::endl;
}

std::pair<int,int> buildEnvMapCDF(GLuint texId)
{
    // Read back the texture size from GL.
    glBindTexture(GL_TEXTURE_2D, texId);
    GLint W = 0, H = 0;
    glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_WIDTH,  &W);
    glGetTexLevelParameteriv(GL_TEXTURE_2D, 0, GL_TEXTURE_HEIGHT, &H);

    // Upload trivial 1×1 tables when there is no real env map.
    if (W <= 1 || H <= 1) {
        std::vector<cl_float> one(1, 1.0f);
        cl_envMarginalCdf   = clw::buffer::create(one, sizeof(cl_float));
        cl_envConditionalCdf = clw::buffer::create(one, sizeof(cl_float));
        cl_envPdf            = clw::buffer::create(one, sizeof(cl_float));
        return {1, 1};
    }

    // Read the RGB float pixels.
    std::vector<cl_float> pixels(W * H * 3);
    glGetTexImage(GL_TEXTURE_2D, 0, GL_RGB, GL_FLOAT, pixels.data());

    const float invW = 1.0f / static_cast<float>(W);
    const float invH = 1.0f / static_cast<float>(H);

    // Per-pixel luminance weighted by sin(theta) for solid-angle measure.
    std::vector<float> lum(W * H);
    for (int y = 0; y < H; ++y) {
        const float theta     = (y + 0.5f) * invH * static_cast<float>(M_PI);
        const float sinTheta  = std::sin(theta);
        for (int x = 0; x < W; ++x) {
            const int idx = y * W + x;
            const float r = pixels[idx * 3 + 0];
            const float g = pixels[idx * 3 + 1];
            const float b = pixels[idx * 3 + 2];
            lum[idx] = (0.2126f * r + 0.7152f * g + 0.0722f * b) * sinTheta;
        }
    }

    // Row sums for marginal distribution.
    std::vector<float> rowSum(H, 0.0f);
    for (int y = 0; y < H; ++y)
        for (int x = 0; x < W; ++x)
            rowSum[y] += lum[y * W + x];

    // Total luminance for PDF normalisation.
    float total = 0.0f;
    for (float v : rowSum) total += v;
    if (total == 0.0f) total = 1.0f; // guard against black env map

    // Marginal CDF (H entries, last entry = 1).
    std::vector<cl_float> margCdf(H);
    {
        float acc = 0.0f;
        for (int y = 0; y < H; ++y) {
            acc += rowSum[y] / total;
            margCdf[y] = acc;
        }
        margCdf[H - 1] = 1.0f; // clamp numerical error
    }

    // Conditional CDFs (W entries per row) and solid-angle PDF.
    std::vector<cl_float> condCdf(W * H);
    std::vector<cl_float> pdf(W * H);

    // Normalisation constant: pdf_SA = pdf_uv / sin(theta) * (H*W) / (2*PI^2)
    const float normConst = static_cast<float>(W * H) /
                            (2.0f * static_cast<float>(M_PI) * static_cast<float>(M_PI));

    for (int y = 0; y < H; ++y) {
        const float rowTotal = rowSum[y] > 0.0f ? rowSum[y] : 1.0f;
        const float theta    = (y + 0.5f) * invH * static_cast<float>(M_PI);
        const float sinTheta = std::sin(theta);
        const float sinInv   = sinTheta > 0.0f ? 1.0f / sinTheta : 0.0f;

        float acc = 0.0f;
        for (int x = 0; x < W; ++x) {
            const int idx = y * W + x;
            acc += lum[idx] / rowTotal;
            condCdf[idx] = acc;

            pdf[idx] = (lum[idx] / total) * normConst * sinInv;
        }
        condCdf[y * W + W - 1] = 1.0f; // clamp numerical error
    }

    cl_envMarginalCdf    = clw::buffer::create(margCdf, sizeof(cl_float) * H);
    cl_envConditionalCdf = clw::buffer::create(condCdf, sizeof(cl_float) * W * H);
    cl_envPdf            = clw::buffer::create(pdf,     sizeof(cl_float) * W * H);

    std::cout << "Built env-map IS tables: " << W << "x" << H
              << " (" << (sizeof(cl_float) * (H + 2 * W * H) / 1024) << " KB)" << std::endl;
    return {W, H};
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

	// Enable profiling only when explicitly needed; it adds measurable overhead.
	queue = cl::CommandQueue(context, device, ENABLE_CL_PROFILING ? CL_QUEUE_PROFILING_ENABLE : 0);

	{
		// Create an OpenCL program with source
		program = cl::Program(context, clw::kernel::parse(kernel_filepath, scene).c_str());

		// Build the program for the selected device and print detailed logs on failure.
		try
		{
			cl_int result = program.build({device}, "-cl-fast-relaxed-math"); // Enable faster math operations
			if (result)
				std::cout << "Error during compilation OpenCL code!!!\n (" << result << ")" << std::endl;
			if (result == CL_BUILD_PROGRAM_FAILURE)
				clw::err::printErrorLog(program, device);
		}
		catch (const cl::BuildError &e)
		{
			std::cerr << "OpenCL build failed: " << e.what() << std::endl;
			for (const auto &buildLog : e.getBuildLog())
			{
				std::cerr << "Build log for " << buildLog.first.getInfo<CL_DEVICE_NAME>() << ":\n"
						  << buildLog.second << std::endl;
			}
			exit(1);
		}
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
	kernel.setArg(0, mBufMeshMatSOA);
	kernel.setArg(1, mBufMeshPosSOA);
	kernel.setArg(2, mBufMeshJokerSOA);
	kernel.setArg(3, mBufMeshTypeSOA);
	kernel.setArg(4, window_width);
	kernel.setArg(5, window_height);
	kernel.setArg(6, scene->object_count);
	kernel.setArg(7, framenumber);
	kernel.setArg(8, cl_camera);
	kernel.setArg(9, rand());
	kernel.setArg(10, rand());
	kernel.setArg(11, cl_screen);

	kernel.setArg(12, mNewBufIndices);
	kernel.setArg(13, mBufVertices);
	kernel.setArg(14, mBufNormals);

	kernel.setArg(15, cl_env_map);
	// SoA path-state buffers (args 16–21)
	kernel.setArg(16, soa_ray_org_t);
	kernel.setArg(17, soa_ray_dir_time);
	kernel.setArg(18, soa_rlh_acc);
	kernel.setArg(19, soa_rlh_mask_pdf);
	kernel.setArg(20, soa_bounce);
	kernel.setArg(21, soa_flags);
	// Remaining args shifted by +5
	kernel.setArg(22, mNewBufBVH);
	kernel.setArg(23, cl_renderParams);
	kernel.setArg(24, g_settings.enableClamping ? (cl_float)g_settings.clampThreshold : 0.0f);
	kernel.setArg(25, cl_envMarginalCdf);
	kernel.setArg(26, cl_envConditionalCdf);
	kernel.setArg(27, cl_envPdf);
	kernel.setArg(28, (cl_int)g_envMapWidth);
	kernel.setArg(29, (cl_int)g_envMapHeight);
	kernel.setArg(30, cl_matTextures);
}

//---------------------------------------------------------------------------------------

// Render statistics tracking
double acc_time(0);
double last_time = 0;
double fps_timer = 0;
int frame_count_for_fps = 0;
double current_fps = 0;
double peak_fps = 0;
double min_fps = 999999.0;
double acc_acquire_ms = 0.0;
double acc_kernel_ms = 0.0;
double acc_release_ms = 0.0;

void runKernel()
{
	try
	{
		// Flush GL command stream; full finish here can over-serialize CPU/GPU work.
		glFlush();

		// Pass in the vector of VBO buffer objects.
		cl::Event acquire_event;
		queue.enqueueAcquireGLObjects(&cl_screens, NULL, &acquire_event);
		acquire_event.wait();
		cl::Event event;

		double tStart = glfwGetTime();
		queue.enqueueNDRangeKernel(kernel, NULL, global_work_size, local_work_size, NULL, &event);
		event.wait();

		double frame_time = glfwGetTime() - tStart;
		acc_time += frame_time;
		if constexpr (ENABLE_CL_PROFILING)
		{
			const cl_ulong acquire_start = acquire_event.getProfilingInfo<CL_PROFILING_COMMAND_START>();
			const cl_ulong acquire_end = acquire_event.getProfilingInfo<CL_PROFILING_COMMAND_END>();
			const cl_ulong kernel_start = event.getProfilingInfo<CL_PROFILING_COMMAND_START>();
			const cl_ulong kernel_end = event.getProfilingInfo<CL_PROFILING_COMMAND_END>();
			acc_acquire_ms += (double)(acquire_end - acquire_start) * 1e-6;
			acc_kernel_ms += (double)(kernel_end - kernel_start) * 1e-6;
		}

		// Calculate FPS every second.
		frame_count_for_fps++;
		fps_timer += frame_time;

		// Release the VBOs so OpenGL can play with them.
		cl::Event release_event;
		queue.enqueueReleaseGLObjects(&cl_screens, NULL, &release_event);
		release_event.wait();
		if constexpr (ENABLE_CL_PROFILING)
		{
			const cl_ulong release_start = release_event.getProfilingInfo<CL_PROFILING_COMMAND_START>();
			const cl_ulong release_end = release_event.getProfilingInfo<CL_PROFILING_COMMAND_END>();
			acc_release_ms += (double)(release_end - release_start) * 1e-6;
		}

		if (fps_timer >= 1.0)
		{ // Update every second
			const double sample_count = frame_count_for_fps > 0 ? (double)frame_count_for_fps : 1.0;
			current_fps = frame_count_for_fps / fps_timer;
			if (current_fps > peak_fps) peak_fps = current_fps;
			if (current_fps < min_fps && frame_count_for_fps > 10) min_fps = current_fps; // Ignore first few frames

			// Display comprehensive render statistics.
			std::cout << "\r[Frame " << framenumber << "] "
					  << "FPS: " << std::fixed << std::setprecision(1) << current_fps << " | "
					  << "Frame Time: " << std::setprecision(3) << (frame_time * 1000) << "ms | "
					  << "Avg: " << (acc_time / framenumber * 1000) << "ms | ";
			if constexpr (ENABLE_CL_PROFILING)
			{
				std::cout << "CL(acq/kern/rel): " << std::setprecision(2)
						  << (acc_acquire_ms / sample_count) << "/"
						  << (acc_kernel_ms / sample_count) << "/"
						  << (acc_release_ms / sample_count) << " ms | ";
			}
			std::cout << "Peak FPS: " << std::setprecision(1) << peak_fps << " | "
					  << "Min FPS: " << (min_fps < 999999.0 ? min_fps : 0) << "    " << std::flush;

			acc_acquire_ms = 0.0;
			acc_kernel_ms = 0.0;
			acc_release_ms = 0.0;
			frame_count_for_fps = 0;
			fps_timer = 0.0;
		}
	}
	catch (const cl::Error &e)
	{
		std::cerr << "\n[OpenCL Runtime Error] " << e.what()
				  << " (" << cl_help::err::getOpenCLErrorCodeStr(e.err())
				  << ")" << std::endl;
		throw;
	}
}

//---------------------------------------------------------------------------------------

void render()
{

	if (buffer_reset)
	{
		// Reset render statistics
		acc_time = 0;
		fps_timer = 0;
		frame_count_for_fps = 0;
		current_fps = 0;
		peak_fps = 0;
		min_fps = 999999.0;
		acc_acquire_ms = 0.0;
		acc_kernel_ms = 0.0;
		acc_release_ms = 0.0;
		
		// Zero all SoA path-state buffers.  Zeroed soa_bounce.s3 (samples==0)
		// triggers the per-path reset logic inside the kernel on the next frame.
		const std::size_t N = static_cast<std::size_t>(window_width) * window_height;
		queue.enqueueFillBuffer(soa_ray_org_t,    0, 0, N * sizeof(cl_float4));
		queue.enqueueFillBuffer(soa_ray_dir_time,  0, 0, N * sizeof(cl_float4));
		queue.enqueueFillBuffer(soa_rlh_acc,       0, 0, N * sizeof(cl_float4));
		queue.enqueueFillBuffer(soa_rlh_mask_pdf,  0, 0, N * sizeof(cl_float4));
		queue.enqueueFillBuffer(soa_bounce,        0, 0, N * sizeof(cl_uint4));
		queue.enqueueFillBuffer(soa_flags,         0, 0, N * sizeof(cl_uint));
		framenumber = 0;
	}
	buffer_reset = false;

	// build a new camera for each frame on the CPU
	interactiveCamera->buildRenderCamera(hostRendercam);
	// copy the host camera to a OpenCL camera
	queue.enqueueWriteBuffer(cl_camera, CL_FALSE, 0, sizeof(Camera), hostRendercam);

	// upload runtime render parameters to GPU
	queue.enqueueWriteBuffer(cl_renderParams, CL_FALSE, 0, sizeof(RenderParams), &g_settings.params);

	kernel.setArg(7, ++framenumber);
	kernel.setArg(8, cl_camera);
	kernel.setArg(9, rand());
	kernel.setArg(10, rand());
	kernel.setArg(24, g_settings.enableClamping ? (cl_float)g_settings.clampThreshold : 0.0f);

	runKernel();

	drawGL();

	// Update exposure uniform (no kernel recompile needed)
	if (g_uExposureLoc >= 0)
		glUniform1f(g_uExposureLoc, g_settings.exposure);

	// Render ImGui overlay; reset accumulation if settings changed
	if (ImGuiLayer::render(g_settings, current_fps, framenumber))
		buffer_reset = true;
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
	try
	{

	// debug statements
#ifndef NDEBUG
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

	// initialise OpenCL (creates context/queue/program — must come first)
	initOpenCL();

	{
		auto [w, h] = buildEnvMapCDF(tex1);
		g_envMapWidth  = w;
		g_envMapHeight = h;
		g_settings.hasEnvMap = (w > 1 && h > 1);
	}

	// Build the per-material texture array (requires OpenCL context to exist).
	buildMatTextureArray(scene);

#ifndef NDEBUG
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
		std::shared_ptr<IO::ModelLoader> ml = std::make_shared<IO::ModelLoader>();
		ml->ImportFromFile(std::string(models_directory + scene->obj_path));

		std::unique_ptr<BVH> bvh = std::make_unique<BVH>(ml);
		std::unique_ptr<std::vector<cl_BVHnode>> nodes = bvh->PrepareData();
		std::size_t bytesBVH = sizeof(cl_BVHnode) * nodes->size();
		mNewBufBVH = clw::buffer::create(*nodes, bytesBVH);

		initOpenCLBuffers_Faces(ml, bvh.get());
	}
	else
	{
		cl_BVHnode dummy{};
		dummy.bbMin[0] = dummy.bbMin[1] = dummy.bbMin[2] = -1e30f; dummy.bbMin[3] = 0.0f;
		dummy.bbMax[0] = dummy.bbMax[1] = dummy.bbMax[2] =  1e30f; dummy.bbMax[3] = 0.0f;
		dummy.first_child_or_primitive = 0; // index 0 → degenerate triangle
		dummy.primitive_count          = 1; // >0 → treated as leaf
		dummy.miss_link                = 0xFFFFFFFFu;
		dummy._pad                     = 0;
		std::vector<cl_BVHnode> dummy_nodes   = { dummy };
		std::vector<cl_uint>    dummy_indices  = { 0u };
		std::vector<cl_float4>  dummy_verts    = { {0.0f, 0.0f, 0.0f, 0.0f} };
		std::vector<cl_float4>  dummy_normals  = { {0.0f, 0.0f, 0.0f, 0.0f} };
		mNewBufBVH     = clw::buffer::create(dummy_nodes,   sizeof(cl_BVHnode));
		mNewBufIndices = clw::buffer::create(dummy_indices,  sizeof(cl_uint));
		mBufVertices   = clw::buffer::create(dummy_verts,   sizeof(cl_float4));
		mBufNormals    = clw::buffer::create(dummy_normals,  sizeof(cl_float4));
	}

	// upload object data as SoA buffers
	initOpenCLBuffers_MeshSoA(scene);

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

	// Allocate SoA per-pixel path-state buffers.
	{
		const std::size_t N = static_cast<std::size_t>(window_width) * window_height;
		soa_ray_org_t    = cl::Buffer(context, CL_MEM_READ_WRITE, N * sizeof(cl_float4));
		soa_ray_dir_time = cl::Buffer(context, CL_MEM_READ_WRITE, N * sizeof(cl_float4));
		soa_rlh_acc      = cl::Buffer(context, CL_MEM_READ_WRITE, N * sizeof(cl_float4));
		soa_rlh_mask_pdf = cl::Buffer(context, CL_MEM_READ_WRITE, N * sizeof(cl_float4));
		soa_bounce       = cl::Buffer(context, CL_MEM_READ_WRITE, N * sizeof(cl_uint4));
		soa_flags        = cl::Buffer(context, CL_MEM_READ_WRITE, N * sizeof(cl_uint));
	}

	// runtime render parameters buffer (written every frame from g_settings)
	cl_renderParams = cl::Buffer(context, CL_MEM_READ_ONLY, sizeof(RenderParams));
	queue.enqueueWriteBuffer(cl_renderParams, CL_TRUE, 0, sizeof(RenderParams), &g_settings.params);

	// intitialise the kernel
	initCLKernel();

	// initialise ImGui (must happen after window + GL context are ready)
	ImGuiLayer::init(window);

	// every pixel in the image has its own thread or "work item",
	// so the total amount of work items equals the number of pixels
	const std::size_t kernel_max_wg = kernel.getWorkGroupInfo<CL_KERNEL_WORK_GROUP_SIZE>(device);
	const std::size_t preferred_multiple = kernel.getWorkGroupInfo<CL_KERNEL_PREFERRED_WORK_GROUP_SIZE_MULTIPLE>(device);
	const cl_ulong private_mem_bytes = kernel.getWorkGroupInfo<CL_KERNEL_PRIVATE_MEM_SIZE>(device);

	// Memory-bound kernels with elevated private memory typically get better occupancy with smaller groups.
	local_work_size = preferred_multiple ? preferred_multiple * 2 : 64;
	if (private_mem_bytes > 0 && private_mem_bytes <= 256)
		local_work_size = preferred_multiple ? preferred_multiple * 4 : 128;
	if (local_work_size > kernel_max_wg)
		local_work_size = kernel_max_wg;
	if (local_work_size > 256)
		local_work_size = 256;
	if (local_work_size == 0)
		local_work_size = 1;

	// Ensure the global work size is a multiple of local work size
	if (global_work_size % local_work_size != 0)
		global_work_size = (global_work_size / local_work_size + 1) * local_work_size;

	std::cout << "Kernel launch config: local=" << local_work_size
			  << ", preferredMultiple=" << preferred_multiple
			  << ", privateMem=" << private_mem_bytes << " bytes" << std::endl;

	std::cout << "Starting render loop..." << std::endl;
	std::cout << "Resolution: " << window_width << "x" << window_height << " (" << global_work_size << " work items)" << std::endl;
	std::cout << "Use WASD/RF to move, Arrow keys to look around, Space to reset camera" << std::endl;
	std::cout << "Press 'P' to save screenshot" << std::endl;
	std::cout << "--------------------------------------------------------------" << std::endl;

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

		ImGuiLayer::shutdown();
		glfwDestroyWindow(window);
		glfwTerminate();
		return 0;
	}
	catch (const cl::Error &e)
	{
		std::cerr << "\n[Fatal OpenCL Error] " << e.what()
				  << " (" << cl_help::err::getOpenCLErrorCodeStr(e.err())
				  << ")" << std::endl;
	}
	catch (const std::exception &e)
	{
		std::cerr << "\n[Fatal Exception] " << e.what() << std::endl;
	}
	catch (...)
	{
		std::cerr << "\n[Fatal Exception] Unknown error" << std::endl;
	}

	ImGuiLayer::shutdown();
	if (window)
		glfwDestroyWindow(window);
	glfwTerminate();
	return EXIT_FAILURE;
}

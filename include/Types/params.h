#pragma once

#include <iostream>
#include <CL/cl.hpp>

struct Camera;
struct host_scene;

constexpr char* models_directory = "../resources/models/";
constexpr char* kernel_filepath = "../kernels/main.cl";

// every pixel in the image has its own thread or "work item",
// so the total amount of work items equals the number of pixels
static std::size_t global_work_size, local_work_size;

// struct RayI {
// 	cl_float3 origin, direction, mask;
// 	cl_uint bounces;
// 	cl_ushort diff_bounces, spec_bounces, trans_bounces, scatter_events;
// };
constexpr std::size_t RayI_size = 16*11;

static cl_uint BVH_NUM_NODES(0);

// current frame number
static cl_uint framenumber = 0;

//-------------------------------------------------------------

// cpu_camera
static Camera* hostRendercam = nullptr;
// host scene
static host_scene* scene = nullptr;
// scene filepath
static std::string scene_filepath = "../scenes/test.json";
// is Alpha testing enabled?
static bool ALPHA_TESTING(false);
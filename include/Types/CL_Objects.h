#pragma once

#include <iostream>
#include <vector>
#include <CL/cl.hpp>

// OpenCL objects
static cl::Device device;
static cl::Context context;
static cl::CommandQueue queue;
static cl::Kernel kernel;
static cl::Program program;

static cl::Buffer cl_output;
static cl::Buffer cl_meshes;
static cl::Buffer cl_camera;
static cl::Buffer cl_accumbuffer;
static cl::ImageGL cl_screen;
static cl::ImageGL cl_env_map;
// clw::ImageGL cl_noise_tex;
static std::vector<cl::Memory> cl_screens;

static cl::Buffer mBufBVH;
static cl::Buffer mBufFacesV;
static cl::Buffer mBufFacesN;
static cl::Buffer mBufVertices;
static cl::Buffer mBufNormals;
static cl::Buffer mBufMaterial;

static cl::Buffer cl_flattenI;
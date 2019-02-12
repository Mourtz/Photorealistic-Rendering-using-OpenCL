#pragma once

#include <iostream>
#include <vector>
#include <CL/cl.hpp>

// OpenCL objects
extern cl::Device device;
extern cl::Context context;
extern cl::CommandQueue queue;
extern cl::Kernel kernel;
extern cl::Program program;

extern cl::Buffer cl_output;
extern cl::Buffer cl_meshes;
extern cl::Buffer cl_camera;
extern cl::Buffer cl_accumbuffer;
extern cl::ImageGL cl_screen;
extern cl::ImageGL cl_env_map;
// clw::ImageGL cl_noise_tex;
extern std::vector<cl::Memory> cl_screens;

extern cl::Buffer mBufBVH;
extern cl::Buffer mBufFacesV;
extern cl::Buffer mBufFacesN;
extern cl::Buffer mBufVertices;
extern cl::Buffer mBufNormals;
extern cl::Buffer mBufMaterial;
extern cl::Buffer cl_flattenI;

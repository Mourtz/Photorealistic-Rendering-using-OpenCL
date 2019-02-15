#pragma once

#include <iostream>
#include <CL/cl.hpp>
#include <utils.h>

extern cl::Context context;

namespace cl_help
{
namespace program
{
inline cl::Program LoadProgram(std::string filepath, std::string opts, std::vector<cl::Device> devices)
{
    cl::Program program = cl::Program(context, utils::ReadFile(filepath).c_str());

    //"-D OBJECTS_SIZE=23"
    // Build the program for the selected device
    cl_int result = program.build(devices, opts.c_str()); // "-cl-fast-relaxed-math"
    if (result)
        std::cout << "Error during compilation OpenCL code!!!\n (" << result << ")" << std::endl;
    if (result == CL_BUILD_PROGRAM_FAILURE)
        std::cerr << "couldn't load the program '" << filepath << "'\n";

    return program;
}
} // namespace program
} // namespace cl_help

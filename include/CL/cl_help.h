#pragma once

#include <iostream>
#include <vector>
#include <string>

#include <CL/cl_program.h>
#include <CL/cl_kernel.h>

extern cl::Context context;

namespace cl_help
{

namespace err
{
inline void expectedError(const char *errorMsg)
{
	std::cout << "Expected Error: " << errorMsg << std::endl;
}

template <typename T>
inline const char *getOpenCLErrorCodeStr(T input)
{
	int errorCode = (int)input;
	switch (errorCode)
	{
	case CL_DEVICE_NOT_FOUND:
		return "CL_DEVICE_NOT_FOUND";
	case CL_DEVICE_NOT_AVAILABLE:
		return "CL_DEVICE_NOT_AVAILABLE";
	case CL_COMPILER_NOT_AVAILABLE:
		return "CL_COMPILER_NOT_AVAILABLE";
	case CL_MEM_OBJECT_ALLOCATION_FAILURE:
		return "CL_MEM_OBJECT_ALLOCATION_FAILURE";
	case CL_OUT_OF_RESOURCES:
		return "CL_OUT_OF_RESOURCES";
	case CL_OUT_OF_HOST_MEMORY:
		return "CL_OUT_OF_HOST_MEMORY";
	case CL_PROFILING_INFO_NOT_AVAILABLE:
		return "CL_PROFILING_INFO_NOT_AVAILABLE";
	case CL_MEM_COPY_OVERLAP:
		return "CL_MEM_COPY_OVERLAP";
	case CL_IMAGE_FORMAT_MISMATCH:
		return "CL_IMAGE_FORMAT_MISMATCH";
	case CL_IMAGE_FORMAT_NOT_SUPPORTED:
		return "CL_IMAGE_FORMAT_NOT_SUPPORTED";
	case CL_BUILD_PROGRAM_FAILURE:
		return "CL_BUILD_PROGRAM_FAILURE";
	case CL_MAP_FAILURE:
		return "CL_MAP_FAILURE";
	case CL_MISALIGNED_SUB_BUFFER_OFFSET:
		return "CL_MISALIGNED_SUB_BUFFER_OFFSET";
	case CL_EXEC_STATUS_ERROR_FOR_EVENTS_IN_WAIT_LIST:
		return "CL_EXEC_STATUS_ERROR_FOR_EVENTS_IN_WAIT_LIST";
	case CL_INVALID_VALUE:
		return "CL_INVALID_VALUE";
	case CL_INVALID_DEVICE_TYPE:
		return "CL_INVALID_DEVICE_TYPE";
	case CL_INVALID_PLATFORM:
		return "CL_INVALID_PLATFORM";
	case CL_INVALID_DEVICE:
		return "CL_INVALID_DEVICE";
	case CL_INVALID_CONTEXT:
		return "CL_INVALID_CONTEXT";
	case CL_INVALID_QUEUE_PROPERTIES:
		return "CL_INVALID_QUEUE_PROPERTIES";
	case CL_INVALID_COMMAND_QUEUE:
		return "CL_INVALID_COMMAND_QUEUE";
	case CL_INVALID_HOST_PTR:
		return "CL_INVALID_HOST_PTR";
	case CL_INVALID_MEM_OBJECT:
		return "CL_INVALID_MEM_OBJECT";
	case CL_INVALID_IMAGE_FORMAT_DESCRIPTOR:
		return "CL_INVALID_IMAGE_FORMAT_DESCRIPTOR";
	case CL_INVALID_IMAGE_SIZE:
		return "CL_INVALID_IMAGE_SIZE";
	case CL_INVALID_SAMPLER:
		return "CL_INVALID_SAMPLER";
	case CL_INVALID_BINARY:
		return "CL_INVALID_BINARY";
	case CL_INVALID_BUILD_OPTIONS:
		return "CL_INVALID_BUILD_OPTIONS";
	case CL_INVALID_PROGRAM:
		return "CL_INVALID_PROGRAM";
	case CL_INVALID_PROGRAM_EXECUTABLE:
		return "CL_INVALID_PROGRAM_EXECUTABLE";
	case CL_INVALID_KERNEL_NAME:
		return "CL_INVALID_KERNEL_NAME";
	case CL_INVALID_KERNEL_DEFINITION:
		return "CL_INVALID_KERNEL_DEFINITION";
	case CL_INVALID_KERNEL:
		return "CL_INVALID_KERNEL";
	case CL_INVALID_ARG_INDEX:
		return "CL_INVALID_ARG_INDEX";
	case CL_INVALID_ARG_VALUE:
		return "CL_INVALID_ARG_VALUE";
	case CL_INVALID_ARG_SIZE:
		return "CL_INVALID_ARG_SIZE";
	case CL_INVALID_KERNEL_ARGS:
		return "CL_INVALID_KERNEL_ARGS";
	case CL_INVALID_WORK_DIMENSION:
		return "CL_INVALID_WORK_DIMENSION";
	case CL_INVALID_WORK_GROUP_SIZE:
		return "CL_INVALID_WORK_GROUP_SIZE";
	case CL_INVALID_WORK_ITEM_SIZE:
		return "CL_INVALID_WORK_ITEM_SIZE";
	case CL_INVALID_GLOBAL_OFFSET:
		return "CL_INVALID_GLOBAL_OFFSET";
	case CL_INVALID_EVENT_WAIT_LIST:
		return "CL_INVALID_EVENT_WAIT_LIST";
	case CL_INVALID_EVENT:
		return "CL_INVALID_EVENT";
	case CL_INVALID_OPERATION:
		return "CL_INVALID_OPERATION";
	case CL_INVALID_GL_OBJECT:
		return "CL_INVALID_GL_OBJECT";
	case CL_INVALID_BUFFER_SIZE:
		return "CL_INVALID_BUFFER_SIZE";
	case CL_INVALID_MIP_LEVEL:
		return "CL_INVALID_MIP_LEVEL";
	case CL_INVALID_GLOBAL_WORK_SIZE:
		return "CL_INVALID_GLOBAL_WORK_SIZE";
	case CL_INVALID_GL_SHAREGROUP_REFERENCE_KHR:
		return "CL_INVALID_GL_SHAREGROUP_REFERENCE_KHR";
	case CL_PLATFORM_NOT_FOUND_KHR:
		return "CL_PLATFORM_NOT_FOUND_KHR";
		//case CL_INVALID_PROPERTY_EXT:
		//    return "CL_INVALID_PROPERTY_EXT";
	case CL_DEVICE_PARTITION_FAILED_EXT:
		return "CL_DEVICE_PARTITION_FAILED_EXT";
	case CL_INVALID_PARTITION_COUNT_EXT:
		return "CL_INVALID_PARTITION_COUNT_EXT";
		//case CL_INVALID_DEVICE_QUEUE:
		//	return "CL_INVALID_DEVICE_QUEUE";
		//case CL_INVALID_PIPE_SIZE:
		//	return "CL_INVALID_PIPE_SIZE";

	default:
		return "unknown error code";
	}
}

inline void error(std::string errorMsg)
{
	std::cout << "Error: " << errorMsg << std::endl;
}

template <typename T>
inline bool checkVal(
	T input,
	T reference,
	std::string message, bool isAPIerror = true)
{
	if (input == reference)
	{
		return false;
	}
	else
	{
		if (isAPIerror)
		{
			std::cout << "Error: " << message << " Error code : ";
			std::cout << getOpenCLErrorCodeStr(input) << std::endl;
		}
		else
		{
			error(message);
		}
		return true;
	}
}

inline void printErrorLog(const cl::Program &program, const cl::Device &device)
{

	// Get the error log and print to console
	std::string buildlog = program.getBuildInfo<CL_PROGRAM_BUILD_LOG>(device);
	std::cerr << "Build log:" << std::endl
			  << buildlog << std::endl;

	// Print the error log to a file
	FILE *log = fopen("errorlog.txt", "w");
	fprintf(log, "%s\n", buildlog.c_str());
	fclose(log);

	std::cout << "Error log saved in 'errorlog.txt'" << std::endl;
	std::cin.get();
	exit(1);
}
} // namespace err

namespace buffer
{
template <typename T>
inline cl::Buffer create(
	std::vector<T>& data,
	std::size_t size,
	cl_mem_flags flags = (CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR))
{
	return cl::Buffer(context, flags, size, &data[0]);
}
} // namespace buffer

//---------------------------------------------------------------------------------------

namespace platform
{
inline void select(cl::Platform &platform, const std::vector<cl::Platform> &platforms)
{

	if (platforms.size() == 1)
		platform = platforms[0];
	else
	{
		int input = 0;
		std::cout << "\nChoose an OpenCL platform: ";
		std::cin >> input;

		// handle incorrect user input
		while (input < 1 || input > platforms.size())
		{
			std::cin.clear();									 //clear errors/bad flags on std::cin
			std::cin.ignore(std::cin.rdbuf()->in_avail(), '\n'); // ignores exact number of chars in std::cin buffer
			std::cout << "No such option. Choose an OpenCL platform: ";
			std::cin >> input;
		}
		platform = platforms[input - 1];
	}
}
}; // namespace platform

//---------------------------------------------------------------------------------------

namespace device
{
inline void select(cl::Device &device, const std::vector<cl::Device> &devices)
{

	if (devices.size() == 1)
		device = devices[0];
	else
	{
		int input = 0;
		std::cout << "\nChoose an OpenCL device: ";
		std::cin >> input;

		// handle incorrect user input
		while (input < 1 || input > devices.size())
		{
			std::cin.clear();									 //clear errors/bad flags on std::cin
			std::cin.ignore(std::cin.rdbuf()->in_avail(), '\n'); // ignores exact number of chars in std::cin buffer
			std::cout << "No such option. Choose an OpenCL device: ";
			std::cin >> input;
		}
		device = devices[input - 1];
	}
}
} // namespace device
} // namespace cl_help

#define OPENCL_EXPECTED_ERROR(msg)        \
	{                                     \
		cl_help::err::expectedError(msg); \
		return EXIT_FAILURE;              \
	}

#define CHECK_OPENCL_ERROR(actual, msg)                                         \
	if (cl_help::err::checkVal(actual, CL_SUCCESS, msg))                        \
	{                                                                           \
		std::cout << "Location : " << __FILE__ << ":" << __LINE__ << std::endl; \
		return EXIT_FAILURE;                                                    \
	}

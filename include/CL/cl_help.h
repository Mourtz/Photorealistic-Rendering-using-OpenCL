#pragma once

#include <iostream>
#include <vector>
#include <string>

#include <CL/cl.hpp>

#include <Scene/scene.h>

cl::Device device;
cl::Context context;
cl::CommandQueue queue;
cl::Kernel kernel;
cl::Program program;

#define OPENCL_EXPECTED_ERROR(msg) \
    { \
        cl_help::expectedError(msg); \
        return EXIT_FAILURE; \
    }

#define CHECK_OPENCL_ERROR(actual, msg) \
    if(cl_help::checkVal(actual, CL_SUCCESS, msg)) \
    { \
        std::cout << "Location : " << __FILE__ << ":" << __LINE__<< std::endl; \
        return EXIT_FAILURE; \
    }

namespace cl_help {
	
	using namespace cl;

	static void expectedError(const char* errorMsg)
	{
		std::cout << "Expected Error: " << errorMsg << std::endl;
	}

	template<typename T>
	static const char* getOpenCLErrorCodeStr(T input)
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

	static void error(std::string errorMsg)
	{
		std::cout << "Error: " << errorMsg << std::endl;
	}

	template<typename T>
	static bool checkVal(
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

	//---------------------------------------------------------------------------------------
	
	template<typename T>
	static inline Buffer createBuffer(
		vector<T> data,
		std::size_t size,
		cl_mem_flags flags = (CL_MEM_READ_ONLY | CL_MEM_COPY_HOST_PTR)
	){
		return Buffer(context, flags, size, &data[0]);
	}

	//---------------------------------------------------------------------------------------

	void pickPlatform(Platform& platform, const std::vector<Platform>& platforms) {

		if (platforms.size() == 1) platform = platforms[0];
		else {
			int input = 0;
			std::cout << "\nChoose an OpenCL platform: ";
			std::cin >> input;

			// handle incorrect user input
			while (input < 1 || input > platforms.size()) {
				std::cin.clear(); //clear errors/bad flags on std::cin
				std::cin.ignore(std::cin.rdbuf()->in_avail(), '\n'); // ignores exact number of chars in std::cin buffer
				std::cout << "No such option. Choose an OpenCL platform: ";
				std::cin >> input;
			}
			platform = platforms[input - 1];
		}
	}

	//---------------------------------------------------------------------------------------

	void pickDevice(Device& device, const std::vector<Device>& devices) {

		if (devices.size() == 1) device = devices[0];
		else {
			int input = 0;
			std::cout << "\nChoose an OpenCL device: ";
			std::cin >> input;

			// handle incorrect user input
			while (input < 1 || input > devices.size()) {
				std::cin.clear(); //clear errors/bad flags on std::cin
				std::cin.ignore(std::cin.rdbuf()->in_avail(), '\n'); // ignores exact number of chars in std::cin buffer
				std::cout << "No such option. Choose an OpenCL device: ";
				std::cin >> input;
			}
			device = devices[input - 1];
		}
	}

	//---------------------------------------------------------------------------------------

	void printErrorLog(const Program& program, const Device& device) {

		// Get the error log and print to console
		std::string buildlog = program.getBuildInfo<CL_PROGRAM_BUILD_LOG>(device);
		std::cerr << "Build log:" << std::endl << buildlog << std::endl;

		// Print the error log to a file
		FILE *log = fopen("errorlog.txt", "w");
		fprintf(log, "%s\n", buildlog.c_str());
		fclose(log);

		std::cout << "Error log saved in 'errorlog.txt'" << std::endl;
		std::cin.get();
		exit(1);
	}

	//---------------------------------------------------------------------------------------
	// definetely not optimized
	std::string loadKernelFile(std::string filepath, host_scene* scene) {
		std::string source;

		std::cout << "----------------------------------------------------------" << std::endl;

		std::ifstream file(filepath);
		if (!file) {
			std::cout << "\nCouldn't find OpenCL file (" + filepath + ')' << std::endl << "Exiting..." << std::endl;
			std::cin.get();
			exit(1);
		}

		std::string line;
		while (std::getline(file, line)) {
			if (line.substr(0, 6) == "#FILE:") {

				std::string filepath = "../kernels/" + line.substr(6);
				std::cout << "Appending (" << filepath << ")\n";
				source += loadKernelFile(filepath, scene);
				continue;
			}

			string temp_name;
			std::size_t temp;

//--------------------------------- RENDER SETTINGS ---------------------------------

			temp_name = "#GLOBAL_MEDIUM#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), (scene->HAS_GLOBAL_MEDIUM ? "#define GLOBAL_MEDIUM" : ""));
				source += line + "\n";
				continue;
			}

			temp_name = "#ALPHA_TESTING#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), (ALPHA_TESTING ? "#define ALPHA_TESTING" : ""));
				source += line + "\n";
				continue;
			}

//--------------------------------- GLOBAL MEDIUM ---------------------------------------------
			if (scene->HAS_GLOBAL_MEDIUM) {
				temp_name = "#GLOBAL_FOG_DENSITY#";
				temp = line.find(temp_name);
				if (temp != string::npos) {
					line.replace(temp, temp_name.length(), std::to_string(scene->GLOBAL_MEDIUM.density) + "f");
					source += line + "\n";
					continue;
				}

				temp_name = "#GLOBAL_FOG_SIGMA_A#";
				temp = line.find(temp_name);
				if (temp != string::npos) {
					line.replace(temp, temp_name.length(), std::to_string(scene->GLOBAL_MEDIUM.sigmaA) + "f");
					source += line + "\n";
					continue;
				}

				temp_name = "#GLOBAL_FOG_SIGMA_S#";
				temp = line.find(temp_name);
				if (temp != string::npos) {
					line.replace(temp, temp_name.length(), std::to_string(scene->GLOBAL_MEDIUM.sigmaS) + "f");
					source += line + "\n";
					continue;
				}

				temp_name = "#GLOBAL_FOG_SIGMA_T#";
				temp = line.find(temp_name);
				if (temp != string::npos) {
					line.replace(temp, temp_name.length(), std::to_string(scene->GLOBAL_MEDIUM.sigmaT) + "f");
					source += line + "\n";
					continue;
				}

				temp_name = "#GLOBAL_FOG_ABS_ONLY#";
				temp = line.find(temp_name);
				if (temp != string::npos) {
					line.replace(temp, temp_name.length(), std::to_string(scene->GLOBAL_MEDIUM.absorptionOnly));
					source += line + "\n";
					continue;
				}
			}	
//------------------------------------------------------------------------------------------------

			temp_name = "#MAX_BOUNCES#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), std::to_string(scene->MAX_BOUNCES));
				source += line + "\n";
				continue;
			}

			temp_name = "#MAX_DIFF_BOUNCES#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), std::to_string(scene->MAX_DIFF_BOUNCES));
				source += line + "\n";
				continue;
			}

			temp_name = "#MAX_SPEC_BOUNCES#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), std::to_string(scene->MAX_SPEC_BOUNCES));
				source += line + "\n";
				continue;
			}

			temp_name = "#MAX_TRANS_BOUNCES#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), std::to_string(scene->MAX_TRANS_BOUNCES));
				source += line + "\n";
				continue;
			}

			temp_name = "#MAX_SCATTERING_EVENTS#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), std::to_string(scene->MAX_SCATTERING_EVENTS));
				source += line + "\n";
				continue;
			}

			temp_name = "#MARCHING_STEPS#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), std::to_string(scene->MARCHING_STEPS));
				source += line + "\n";
				continue;
			}

			temp_name = "#SHADOW_MARCHING_STEPS#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), std::to_string(scene->SHADOW_MARCHING_STEPS));
				source += line + "\n";
				continue;
			}

//--------------------------------- MESH TYPES ---------------------------------

			temp = line.find("#INC_SPHERE#");
			if (temp != string::npos) {
				if (scene->H_SPHERE) {
					std::cout << "Appending (../kernels/geometry/sphere.cl)\n";
					source += loadKernelFile("../kernels/geometry/sphere.cl", scene);
				}
				continue;
			}

			temp = line.find("#INC_SDF#");
			if (temp != string::npos) {
				if (scene->H_SDF) {
					std::cout << "Appending (../kernels/geometry/sdf.cl)\n";
					source += loadKernelFile("../kernels/geometry/sdf.cl", scene);
				}
				continue;
			}

			temp = line.find("#INC_BOX#");
			if (temp != string::npos) {
				if (scene->H_BOX) {
					std::cout << "Appending (../kernels/geometry/box.cl)\n";
					source += loadKernelFile("../kernels/geometry/box.cl", scene);
				}
				continue;
			}

			temp = line.find("#INC_QUAD#");
			if (temp != string::npos) {
				if (scene->H_QUAD) {
					std::cout << "Appending (../kernels/geometry/quad.cl)\n";
					source += loadKernelFile("../kernels/geometry/quad.cl", scene);
				}
				continue;
			}

			temp_name = "#SPHERE#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), std::to_string(SPHERE));
				source += line + "\n";
				continue;
			}

			temp_name = "#BOX#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), std::to_string(BOX));
				source += line + "\n";
				continue;
			}

			temp_name = "#SDF#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), std::to_string(SDF));
				source += line + "\n";
				continue;
			}

			temp_name = "#QUAD#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), std::to_string(QUAD));
				source += line + "\n";
				continue;
			}

//--------------------------------- MATERIAL TYPES ---------------------------------

			temp_name = "#LIGHT#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				if (scene->ACTIVE_MATS & LIGHT) {
					line.replace(temp, temp_name.length(), std::to_string(LIGHT));
					source += line + "\n";
				}
				continue;
			}

			temp_name = "#DIFF#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				if (scene->ACTIVE_MATS & DIFF) {
					line.replace(temp, temp_name.length(), std::to_string(DIFF));
					source += line + "\n";
				}

				continue;
			}

			temp_name = "#COND#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				if (scene->ACTIVE_MATS & COND) {
					line.replace(temp, temp_name.length(), std::to_string(COND));
					source += line + "\n";
				}
				continue;
			}

			temp_name = "#ROUGH_COND#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				if (scene->ACTIVE_MATS & ROUGH_COND) {
					line.replace(temp, temp_name.length(), std::to_string(ROUGH_COND));
					source += line + "\n";
				}
				continue;
			}

			temp_name = "#DIEL#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				if (scene->ACTIVE_MATS & DIEL) {
					line.replace(temp, temp_name.length(), std::to_string(DIEL));
					source += line + "\n";
				}
				continue;
			}

			temp_name = "#ROUGH_DIEL#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				if (scene->ACTIVE_MATS & ROUGH_DIEL) {
					line.replace(temp, temp_name.length(), std::to_string(ROUGH_DIEL));
					source += line + "\n";
				}
				continue;
			}

			temp_name = "#COAT#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				if (scene->ACTIVE_MATS & COAT) {
					line.replace(temp, temp_name.length(), std::to_string(COAT));
					source += line + "\n";
				}
				continue;
			}

			temp_name = "#VOL#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				if (scene->ACTIVE_MATS & VOL) {
					line.replace(temp, temp_name.length(), std::to_string(VOL));
					source += line + "\n";
				}
				continue;
			}

			temp_name = "#TRANS#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				if (scene->ACTIVE_MATS & TRANS) {
					line.replace(temp, temp_name.length(), std::to_string(TRANS));
					source += line + "\n";
				}
				continue;
			}

			temp_name = "#SPECSUB#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				if (scene->ACTIVE_MATS & SPECSUB) {
					line.replace(temp, temp_name.length(), std::to_string(SPECSUB));
					source += line + "\n";
				}
				continue;
			}

			temp_name = "#ABS_REFR#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), std::to_string(ABS_REFR));
				source += line + "\n";
				continue;
			}

			temp_name = "#ABS_REFR2#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), std::to_string(ABS_REFR2));
				source += line + "\n";
				continue;
			}

//--------------------------------- LIGHT ---------------------------------

			if (scene->LIGHT_COUNT) {

				temp_name = "#LIGHT_COUNT#";
				temp = line.find(temp_name);
				if (temp != string::npos) {
					line.replace(temp, temp_name.length(), std::to_string(scene->LIGHT_COUNT));
					source += line + "\n";
					continue;
				}

				temp_name = "#INV_LIGHT_COUNT#";
				temp = line.find(temp_name);
				if (temp != string::npos) {
					line.replace(temp, temp_name.length(), std::to_string(1.0f / scene->LIGHT_COUNT) + "f");
					source += line + "\n";
					continue;
				}

				temp_name = "#LIGHT_INDICES#";
				temp = line.find(temp_name);
				if (temp != string::npos) {
					string res = "";
					for (cl_uint i = 0; i < scene->LIGHT_COUNT; ++i)
						res += std::to_string(scene->LIGHT_INDICES[i]) + ((i != (scene->LIGHT_COUNT - 1)) ? "," : "");

					line.replace(temp, temp_name.length(), res);
					source += line + "\n";
					continue;
				}
			}

//--------------------------------- SDF TYPES ---------------------------------

			temp_name = "#SDF_SPHERE#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), std::to_string(SDF_SPHERE));
				source += line + "\n";
				continue;
			}

			temp_name = "#SDF_BOX#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), std::to_string(SDF_BOX));
				source += line + "\n";
				continue;
			}

			temp_name = "#SDF_ROUND_BOX#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), std::to_string(SDF_ROUND_BOX));
				source += line + "\n";
				continue;
			}

			temp_name = "#SDF_PLANE#";
			temp = line.find(temp_name);
			if (temp != string::npos) {
				line.replace(temp, temp_name.length(), std::to_string(SDF_PLANE));
				source += line + "\n";
				continue;
			}

//-----------------------------------------------------------------------------

			source += line + "\n";
		}

		return source;
	}

}
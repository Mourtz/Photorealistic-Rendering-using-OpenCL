cmake_minimum_required(VERSION 3.30)

# Set up CMake variables

# set VCPKG_ROOT per platform
if(WIN32)
    set(VCPKG_ROOT "C:/dev/vcpkg/")
elseif(UNIX)
    set(VCPKG_ROOT "/home/user/vcpkg/")
endif()

set(CMAKE_TOOLCHAIN_FILE "${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")
set(vcpkg_DIR "${VCPKG_ROOT}")
set(CMAKE_PREFIX_PATH "${VCPKG_ROOT}")

SET(PROJECT_NAME "OpenCL_Pathtracer")
SET(TRACER_TARGET "OpenCL_Pathtracer")

PROJECT(${TRACER_TARGET})

# First for the generic no-config case (e.g. with mingw)
set( CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin )
set( CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib )
set( CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib )
# Second, for multi-config builds (e.g. msvc)
foreach( OUTPUTCONFIG ${CMAKE_CONFIGURATION_TYPES} )
    string( TOUPPER ${OUTPUTCONFIG} OUTPUTCONFIG )
    set( CMAKE_RUNTIME_OUTPUT_DIRECTORY_${OUTPUTCONFIG} ${CMAKE_BINARY_DIR}/bin )
    set( CMAKE_LIBRARY_OUTPUT_DIRECTORY_${OUTPUTCONFIG} ${CMAKE_BINARY_DIR}/lib )
    set( CMAKE_ARCHIVE_OUTPUT_DIRECTORY_${OUTPUTCONFIG} ${CMAKE_BINARY_DIR}/lib )
endforeach( OUTPUTCONFIG CMAKE_CONFIGURATION_TYPES )

function(assign_source_group)
    foreach(_source IN ITEMS ${ARGN})
        if (IS_ABSOLUTE "${_source}")
            file(RELATIVE_PATH _source_rel "${CMAKE_CURRENT_SOURCE_DIR}" "${_source}")
        else()
            set(_source_rel "${_source}")
        endif()
        get_filename_component(_source_path "${_source_rel}" PATH)
        string(REPLACE "/" "\\" _source_path_msvc "${_source_path}")
        source_group("${_source_path_msvc}" FILES "${_source}")
    endforeach()
endfunction(assign_source_group)

# Enable VCPKG support
include(${CMAKE_TOOLCHAIN_FILE})

FILE( GLOB_RECURSE SRCS "${CMAKE_SOURCE_DIR}/src/*.cpp" )
FILE( GLOB_RECURSE INC "${CMAKE_SOURCE_DIR}/include/*.h")
FILE( GLOB_RECURSE CL_SRCS "${CMAKE_SOURCE_DIR}/kernels/*.cl" )
FILE( GLOB_RECURSE SHADERS "${CMAKE_SOURCE_DIR}/shaders/*.glsl" )
FILE( GLOB_RECURSE SCENES "${CMAKE_SOURCE_DIR}/scenes/*.json" )

if(WIN32)
	assign_source_group(${SRCS})
	assign_source_group(${INC})
  	assign_source_group(${CL_SRCS})
  	assign_source_group(${SHADERS})
  	assign_source_group(${SCENES})
ENDIF(WIN32)

add_executable(${TRACER_TARGET} ${SRCS} ${INC} ${CL_SRCS} ${SHADERS} ${SCENES})

SET_TARGET_PROPERTIES(${TRACER_TARGET} PROPERTIES
 CXX_STANDARD 17
 CXX_STANDARD_REQUIRED ON)

# add the include directories
TARGET_INCLUDE_DIRECTORIES(${TRACER_TARGET} PUBLIC "${CMAKE_SOURCE_DIR}/include" "${CMAKE_SOURCE_DIR}/external")

IF(UNIX)
    IF(APPLE)
        TARGET_COMPILE_DEFINITIONS(${TRACER_TARGET} PRIVATE -DOS_MAC)
    ELSE(APPLE)
        TARGET_COMPILE_DEFINITIONS(${TRACER_TARGET} PRIVATE -DOS_LNX)
    ENDIF(APPLE)
ELSE(UNIX)
    TARGET_COMPILE_DEFINITIONS(${TRACER_TARGET} PRIVATE -DOS_WIN)
ENDIF(UNIX)

################################
# Compile Flags
################################

SET_TARGET_PROPERTIES(${TRACER_TARGET} PROPERTIES
 CXX_STANDARD 20
 CXX_STANDARD_REQUIRED ON)

 SET(RAYTRACER_COMPILE_FLAGS)
 # set C++ standard
 LIST(APPEND RAYTRACER_COMPILE_FLAGS "-std=c++20")
 # -fexceptions: enables exceptions
 LIST(APPEND RAYTRACER_COMPILE_FLAGS "-fexceptions")
 # -frtti: enables runtime type check (required for virtual functions, etc.)
 LIST(APPEND RAYTRACER_COMPILE_FLAGS "-frtti")
 # -Wall: displays all warnings
 LIST(APPEND RAYTRACER_COMPILE_FLAGS "-Wall")
 
 TARGET_COMPILE_OPTIONS(${TRACER_TARGET} PUBLIC "${RAYTRACER_COMPILE_FLAGS}")

################################
# Dependencies
################################ 

# OpenGL
find_package(OpenGL REQUIRED)
TARGET_INCLUDE_DIRECTORIES(${TRACER_TARGET} PRIVATE ${OPENGL_INCLUDE_DIR})
TARGET_LINK_LIBRARIES(${TRACER_TARGET} PRIVATE ${OPENGL_LIBRARIES})

# BVH
add_subdirectory("external/bvh")
target_link_libraries(${TRACER_TARGET} PRIVATE "bvh")
target_include_directories(${TRACER_TARGET} PRIVATE "external/bvh/src")

# Ensure bvh uses C++20
set_target_properties(bvh PROPERTIES CXX_STANDARD 20 CXX_STANDARD_REQUIRED ON)

find_package(GLEW REQUIRED)
include_directories(${GLEW_INCLUDE_DIRS})
target_link_libraries(${TRACER_TARGET} PRIVATE GLEW::GLEW)

find_package(glfw3 CONFIG REQUIRED)
target_link_libraries(${TRACER_TARGET} PRIVATE glfw)

find_package(Eigen3 CONFIG REQUIRED)
target_link_libraries(${TRACER_TARGET} PRIVATE Eigen3::Eigen)

find_package(OpenCL CONFIG REQUIRED)

# Khronos OpenCL ICD Loader
target_link_libraries(${TRACER_TARGET} PRIVATE OpenCL::OpenCL)

# Khronos OpenCL Headers and C++ bindings
target_link_libraries(${TRACER_TARGET} PRIVATE OpenCL::Headers)
target_link_libraries(${TRACER_TARGET} PRIVATE OpenCL::HeadersCpp)

# OpenCL Utility Library and C++ bindings
target_link_libraries(${TRACER_TARGET} PRIVATE OpenCL::Utils)
target_link_libraries(${TRACER_TARGET} PRIVATE OpenCL::UtilsCpp)

find_package(assimp CONFIG REQUIRED)
target_link_libraries(${TRACER_TARGET} PRIVATE assimp::assimp)

find_package(RapidJSON CONFIG REQUIRED)
target_link_libraries(${TRACER_TARGET} PRIVATE rapidjson)

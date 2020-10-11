CMAKE_MINIMUM_REQUIRED(VERSION 3.0.2)

SET(PROJECT_NAME "OpenCL_Pathtracer")
SET(TRACER_TARGET "OpenCL_Pathtracer")

PROJECT(${TRACER_TARGET})

SET(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
SET(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_CURRENT_SOURCE_DIR}/external/assimp/cmake-modules")
SET(CMAKE_PREFIX_PATH ${CMAKE_PREFIX_PATH} "${CMAKE_SOURCE_DIR}/external/assimp")

IF(COMMAND cmake_policy)
  if (POLICY CMP0043)
    cmake_policy(SET CMP0043 NEW)
  endif()
ENDIF(COMMAND cmake_policy)

IF(NOT CMAKE_BUILD_TYPE MATCHES Release)
  # Add "DEBUG"   
  IF(CMAKE_BUILD_TYPE MATCHES Debug)
    add_definitions(-DDEBUG)
  ENDIF()
  # Enable "Profiling" for all modes except "Release"
  add_definitions(-DPROFILING)
ENDIF()


##############################################################
# output paths
##############################################################

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

# https://stackoverflow.com/questions/31422680/how-to-set-visual-studio-filters-for-nested-sub-directory-using-cmake
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

# OS Definitions
IF(UNIX)
    IF(APPLE)
        SET(CMAKE_MACOSX_RPATH ON)
        SET(CMAKE_SKIP_BUILD_RPATH  FALSE)
        SET(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)
        SET(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}")
        SET(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

        LIST(FIND CMAKE_PLATFORM_IMPLICIT_LINK_DIRECTORIES "${CMAKE_INSTALL_PREFIX}" isSystemDir)
        IF("${isSystemDir}" STREQUAL "-1")
            SET(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}")
        ENDIF("${isSystemDir}" STREQUAL "-1")
    ENDIF(APPLE)
ENDIF(UNIX)

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

################################
# Target Definitions
################################

ADD_EXECUTABLE(${TRACER_TARGET} ${SRCS} ${INC} ${CL_SRCS} ${SHADERS} ${SCENES})

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
 CXX_STANDARD 17
 CXX_STANDARD_REQUIRED ON)

 SET(RAYTRACER_COMPILE_FLAGS)
 # set C++ standard
 LIST(APPEND RAYTRACER_COMPILE_FLAGS "-std=c++17")
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
FIND_PACKAGE(OpenGL REQUIRED)
TARGET_INCLUDE_DIRECTORIES(${TRACER_TARGET} PRIVATE ${OPENGL_INCLUDE_DIR})
TARGET_LINK_LIBRARIES(${TRACER_TARGET} PRIVATE ${OPENGL_LIBRARIES})

#OpenCL 
FIND_PACKAGE(OpenCL REQUIRED)
TARGET_INCLUDE_DIRECTORIES(${TRACER_TARGET} PRIVATE ${OpenCL_INCLUDE_DIRS})
TARGET_LINK_LIBRARIES(${TRACER_TARGET} PRIVATE ${OpenCL_LIBRARIES})

# X11
IF(APPLE)
    FIND_PACKAGE(X11 REQUIRED)
    TARGET_INCLUDE_DIRECTORIES(${TRACER_TARGET} PRIVATE ${X11_INCLUDE_DIR})
    TARGET_LINK_LIBRARIES(${TRACER_TARGET} PRIVATE ${X11_LIBS})
ENDIF(APPLE)

# GLFW
FIND_PACKAGE(GLFW)
IF(GLFW_FOUND)
    TARGET_INCLUDE_DIRECTORIES(${TRACER_TARGET} PRIVATE ${GLFW_INCLUDE_DIR})
    TARGET_LINK_LIBRARIES(${TRACER_TARGET} PRIVATE ${GLFW_LIBRARY})
ELSE()
    set(GLFW_DIR "${CMAKE_SOURCE_DIR}/external/glfw")
    set(GLFW_BUILD_DOCS OFF CACHE BOOL "" FORCE)
    set(GLFW_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(BUILD_SHARED_LIBS ON CACHE BOOL "" FORCE)
    add_subdirectory("${GLFW_DIR}")
    target_link_libraries(${TRACER_TARGET} PRIVATE "glfw" "${GLFW_LIBRARIES}")
    target_include_directories(${TRACER_TARGET} PRIVATE "${GLFW_DIR}/include")
    target_compile_definitions(${TRACER_TARGET} PRIVATE "GLFW_INCLUDE_NONE")
ENDIF()

# GLEW
FIND_PACKAGE(GLEW)
IF(GLEW_FOUND)
  MESSAGE(STATUS "Found GLEW on system, using that...")
  TARGET_INCLUDE_DIRECTORIES(${TRACER_TARGET} PRIVATE ${GLEW_INCLUDE_DIRS})
  TARGET_LINK_LIBRARIES(${TRACER_TARGET} PRIVATE ${GLEW_LIBRARIES})
ELSE()
  SET(GLEW_LIBRARIES GLEW::glew)
  MESSAGE(STATUS "Compiling GLEW from external submodules...")
  set(GLEW_DIR "${CMAKE_SOURCE_DIR}/external/glew-cmake")
  set(glew-cmake_BUILD_SHARED ON)
  set(glew-cmake_BUILD_STATIC OFF)
  set(PKG_CONFIG_REPRESENTATIVE_TARGET OFF)
  set(ONLY_LIBS ON)
  add_subdirectory("${GLEW_DIR}")

  target_include_directories(${TRACER_TARGET} PRIVATE "${GLEW_DIR}/include")
  target_link_libraries(${TRACER_TARGET} PRIVATE debug "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/glewd.lib" optimized "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/glew.lib")
  
  # copy DLLs
  #   GET_TARGET_PROPERTY(DLL_PATH ${GLEW_LIBRARIES} IMPORTED_LOCATION_RELEASE)
  #   FILE(COPY ${DLL_PATH} DESTINATION "../bin")
ENDIF()

# OpenMP
find_package(OpenMP QUIET)
if (OpenMP_CXX_FOUND)
    target_link_libraries(${TRACER_TARGET} INTERFACE ${OpenMP_CXX_LIBRARIES})
    target_include_directories(${TRACER_TARGET} INTERFACE ${OpenMP_CXX_INCLUDE_DIRS})
    if(${CMAKE_VERSION} VERSION_GREATER "3.13.0") 
        target_link_options(${TRACER_TARGET} INTERFACE ${OpenMP_CXX_FLAGS})
    endif()
    target_compile_options(${TRACER_TARGET} INTERFACE ${OpenMP_CXX_FLAGS})
endif ()

# Assimp
FIND_PACKAGE(assimp REQUIRED)
IF(assimp_FOUND)
    target_include_directories(${TRACER_TARGET} PRIVATE ${assimp_INCLUDE_DIRS})
    target_link_libraries(${TRACER_TARGET} PRIVATE ${assimp_LIBRARIES})
ELSE()
    set(ASSIMP_DIR "${CMAKE_SOURCE_DIR}/external/assimp")
    set(ASSIMP_INSTALL OFF)
    set(ASSIMP_BUILD_TESTS OFF)
    set(ASSIMP_BUILD_ASSIMP_TOOLS OFF)
    set(ASSIMP_BUILD_SAMPLES OFF)
    add_subdirectory("${ASSIMP_DIR}")
    target_include_directories(${TRACER_TARGET} PRIVATE "${ASSIMP_DIR}/include")
    target_link_libraries(${TRACER_TARGET} PRIVATE "assimp")
ENDIF()


# BVH
add_subdirectory("external/bvh")
target_link_libraries(${TRACER_TARGET} PRIVATE "bvh")

# # TBB
# SET(EMBREE_TBB_DEBUG_ROOT "${CMAKE_SOURCE_DIR}/external/embree")
# SET(EMBREE_TBB_ROOT "${CMAKE_SOURCE_DIR}/external/embree")

# EMBREE
# set(EMBREE_DIR "external/embree")
# set(EMBREE_STATIC_LIB ON CACHE BOOL "Build Embree as a static library." FORCE)
# set(EMBREE_ISPC_SUPPORT OFF CACHE BOOL "Build Embree with support for ISPC applications." FORCE)
# set(EMBREE_TUTORIALS OFF CACHE BOOL "Enable to build Embree tutorials" FORCE)
# set(EMBREE_STAT_COUNTERS OFF CACHE BOOL "Enables statistic counters." FORCE)
# set(EMBREE_RAY_MASK OFF CACHE BOOL "Enables ray mask support." FORCE)
# set(EMBREE_BACKFACE_CULLING OFF CACHE BOOL "Enables backface culling." FORCE)
# set(EMBREE_INTERSECTION_FILTER ON CACHE BOOL "Enables intersection filter callback." FORCE)
# set(EMBREE_INTERSECTION_FILTER_RESTORE ON CACHE BOOL "Restores previous hit when hit is filtered out." FORCE)
# set(EMBREE_TASKING_SYSTEM "INTERNAL" CACHE STRING "Selects tasking system" FORCE)
# set(EMBREE_STATIC_RUNTIME OFF CACHE BOOL "Use the static version of the C/C++ runtime library." FORCE)
# add_subdirectory("${EMBREE_DIR}")
# add_definitions(-DEMBREE_STATIC_LIB=1)
# target_include_directories(${TRACER_TARGET} PRIVATE "${EMBREE_DIR}/include")
# target_link_libraries(${TRACER_TARGET} "embree")

# set(AMD_APP_SDK "./external")
#
# include_directories(
#   ${AMD_APP_SDK}/include
#   ${CMAKE_SOURCE_DIR}/include
# )
# link_directories(${AMD_APP_SDK}/lib/x86)
#
# FILE( GLOB SRCS "src/*.cpp" )
# FILE( GLOB INC "include/*.h")
# FILE( GLOB CL_SRCS "kernels/*.cl" )
#
# ADD_EXECUTABLE(${TRACER_TARGET} ${SRCS} ${INC} ${CL_SRCS})
#
# target_link_libraries( ${TRACER_TARGET} OpenCL glut32 glew32 )
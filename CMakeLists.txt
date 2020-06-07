CMAKE_MINIMUM_REQUIRED(VERSION 3.0.2)

PROJECT( OpenCL_Pathtracer )

set(CMAKE_CXX_STANDARD 14)
SET(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

##############################################################
# output paths
##############################################################
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

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

IF(UNIX)
    ADD_DEFINITIONS(-Wall -std=c++11 -fvisibility=hidden)
ENDIF()

# OS Definitions
IF(UNIX)
    IF(APPLE)
        ADD_DEFINITIONS(-DOS_MAC)
        SET(CMAKE_MACOSX_RPATH ON)
        SET(CMAKE_SKIP_BUILD_RPATH  FALSE)
        SET(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)
        SET(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}")
        SET(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)

        LIST(FIND CMAKE_PLATFORM_IMPLICIT_LINK_DIRECTORIES "${CMAKE_INSTALL_PREFIX}" isSystemDir)
        IF("${isSystemDir}" STREQUAL "-1")
            SET(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}")
        ENDIF("${isSystemDir}" STREQUAL "-1")
    ELSE(APPLE)
        ADD_DEFINITIONS(-DOS_LNX)
    ENDIF(APPLE)
ELSE(UNIX)
    ADD_DEFINITIONS(-DOS_WIN -DNOMINMAX)
ENDIF(UNIX)

SET(X11_LIBS "")
IF(APPLE)
    FIND_PACKAGE(X11 REQUIRED)
    INCLUDE_DIRECTORIES(${X11_INCLUDE_DIR})
    SET(X11_LIBS ${X11_LIBRARIES})
ENDIF(APPLE)

# Profiling Option
ADD_DEFINITIONS(-DPROFILING)

FIND_PACKAGE(OpenGL REQUIRED)
FIND_PACKAGE(OpenCL REQUIRED)
FIND_PACKAGE(OpenMP)

if (OPENMP_FOUND)
    set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${OpenMP_C_FLAGS}")
    set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS}")
    set (CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${OpenMP_EXE_LINKER_FLAGS}")
endif()

INCLUDE_DIRECTORIES(
    ${OPENGL_INCLUDE_DIR}
    ${GLFW_INCLUDE_DIR}
    ${OpenCL_INCLUDE_DIRS}
    "${CMAKE_SOURCE_DIR}/include"
    "${CMAKE_SOURCE_DIR}/external"
)

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

ADD_EXECUTABLE(${PROJECT_NAME} ${SRCS} ${INC} ${CL_SRCS} ${SHADERS} ${SCENES})

# if(MSVC)
# 	SET_TARGET_PROPERTIES(${PROJECT_NAME} PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY} )
# 	SET_TARGET_PROPERTIES(${PROJECT_NAME} PROPERTIES RUNTIME_OUTPUT_DIRECTORY_DEBUG ${CMAKE_RUNTIME_OUTPUT_DIRECTORY} )
# 	SET_TARGET_PROPERTIES(${PROJECT_NAME} PROPERTIES RUNTIME_OUTPUT_DIRECTORY_RELEASE ${CMAKE_RUNTIME_OUTPUT_DIRECTORY} )
# ENDIF(MSVC)

TARGET_LINK_LIBRARIES(${PROJECT_NAME}
    ${OPENGL_LIBRARIES}
    ${GLFW_LIBRARY}
    ${OpenCL_LIBRARIES}
    ${X11_LIBS}
)

# GLFW
set(GLFW_DIR "${CMAKE_SOURCE_DIR}/external/glfw")
set(GLFW_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(GLFW_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
add_subdirectory("${GLFW_DIR}")
target_link_libraries(${PROJECT_NAME} "glfw" "${GLFW_LIBRARIES}")
target_include_directories(${PROJECT_NAME} PRIVATE "${GLFW_DIR}/include")
target_compile_definitions(${PROJECT_NAME} PRIVATE "GLFW_INCLUDE_NONE")

# GLEW
set(GLEW_DIR "${CMAKE_SOURCE_DIR}/external/glew-cmake")
set(glew-cmake_BUILD_SHARED ON)
set(glew-cmake_BUILD_STATIC OFF)
set(glew-cmake_BUILD_MULTI_CONTEXT OFF)
set(ONLY_LIBS ON)
add_subdirectory("${GLEW_DIR}")
target_include_directories(${PROJECT_NAME} PRIVATE "${GLEW_DIR}/include")

target_link_libraries(${PROJECT_NAME} "${CMAKE_SOURCE_DIR}/build/lib/Debug/glewd.lib")

# Assimp
set(ASSIMP_DIR "${CMAKE_SOURCE_DIR}/external/assimp")
add_subdirectory("${ASSIMP_DIR}")
target_include_directories(${PROJECT_NAME} PRIVATE "${ASSIMP_DIR}/include")
target_link_libraries(${PROJECT_NAME} "assimp")

# # TBB
# SET(EMBREE_TBB_DEBUG_ROOT "${CMAKE_SOURCE_DIR}/external/embree")
# SET(EMBREE_TBB_ROOT "${CMAKE_SOURCE_DIR}/external/embree")

# # EMBREE
# set(EMBREE_DIR "${CMAKE_SOURCE_DIR}/external/embree")
# INCLUDE("${EMBREE_DIR}/common/cmake/embree-config.cmake")
# SET(ENABLE_TUTORIALS OFF)
# SET(ENABLE_INSTALLER OFF)
# set(EMBREE_ISPC_SUPPORT OFF)
# add_subdirectory("${EMBREE_DIR}")
# target_include_directories(${PROJECT_NAME} PRIVATE "${EMBREE_DIR}/include")
# target_link_libraries(${PROJECT_NAME} "embree")

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
# ADD_EXECUTABLE(${PROJECT_NAME} ${SRCS} ${INC} ${CL_SRCS})
#
# target_link_libraries( ${PROJECT_NAME} OpenCL glut32 glew32 )
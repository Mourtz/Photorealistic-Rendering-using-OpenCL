/**
 * Web version of OpenCL Pathtracer using WebGPU
 * @author Alex Mourtziapis - 2019 (Desktop version)
 * Web adaptation - 2025
 */

#define NOMINMAX

#include <iostream>
#include <cstdlib>
#include <fstream>
#include <vector>
#include <string>
#include <memory>

#include <rapidjson/document.h>
#include <rapidjson/istreamwrapper.h>

#ifdef EMSCRIPTEN
#include <emscripten.h>
#include <emscripten/html5.h>
#include <emscripten/html5_webgpu.h>
#include <webgpu/webgpu.h>
#else
#include <GL/glew.h>
#endif

#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>

//----------------------------------------------

constexpr const char *models_directory = "/resources/models/";
constexpr const char *kernel_filepath = "/kernels/main.cl";
constexpr std::size_t RayI_size = 16 * 7;

//----------------------------------------------

#include <Camera/camera.h>
#include <Scene/scene.h>
#include <Model/model_loader.h>
#include <BVH/bvh.h>

#ifdef EMSCRIPTEN
#include "webgpu_renderer.h"
#include "web_scene.h"
#else
#include <GL/cl_gl_interop.h>
#include <CL/cl_help.h>
namespace clw = cl_help;
#endif

using namespace CL_RAYTRACER;

// Global variables
int window_width = 1280;
int window_height = 720;
std::string env_map_filepath = "";
unsigned char encoder = 0;

GLFWwindow* window = nullptr;
Camera *hostRendercam = nullptr;
InteractiveCamera *interactiveCamera = nullptr;
host_scene *scene = nullptr;
std::string scene_filepath = "/scenes/cornell.json";
bool ALPHA_TESTING = false;

#ifdef EMSCRIPTEN
std::unique_ptr<WebGPURenderer> renderer;
#else
// OpenCL variables (fallback)
cl::Device device;
cl::Context context;
cl::CommandQueue queue;
cl::Kernel kernel;
cl::Program program;
#endif

cl_uint framenumber = 0;
bool buffer_reset = true;
bool render_to_file = false;

// Forward declarations
void initCamera();
void render();
bool initGL();

// Main render loop function for Emscripten
void main_loop() {
    render();
    glfwSwapBuffers(window);
    glfwPollEvents();
    
    if (render_to_file) {
        // Handle screenshot/export
        render_to_file = false;
    }
}

bool initGL() {
    if (!glfwInit()) {
        std::cerr << "Failed to initialize GLFW" << std::endl;
        return false;
    }
    
    std::cout << "GLFW initialized!" << std::endl;
    
    // Set window hints for WebGL/WebGPU
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
    glfwWindowHint(GLFW_CLIENT_API, GLFW_OPENGL_ES_API);
    glfwWindowHint(GLFW_RESIZABLE, GL_FALSE);
    
    window = glfwCreateWindow(window_width, window_height, "OpenCL-Pathtracer Web", NULL, NULL);
    if (!window) {
        std::cerr << "Failed to create GLFW window" << std::endl;
        glfwTerminate();
        return false;
    }
    
    glfwMakeContextCurrent(window);
    
    // Set callbacks
    glfwSetKeyCallback(window, key_callback);
    glfwSetMouseButtonCallback(window, mouse_button_callback);
    glfwSetCursorPosCallback(window, cursor_pos_callback);
    glfwSetScrollCallback(window, scroll_callback);
    
#ifdef EMSCRIPTEN
    // Initialize WebGPU renderer
    renderer = std::make_unique<WebGPURenderer>(window_width, window_height);
    if (!renderer->initialize()) {
        std::cerr << "Failed to initialize WebGPU renderer" << std::endl;
        return false;
    }
#else
    // Initialize OpenGL (fallback)
    if (glewInit() != GLEW_OK) {
        std::cerr << "Failed to initialize GLEW" << std::endl;
        return false;
    }
#endif
    
    std::cout << "Graphics initialized" << std::endl;
    return true;
}

void initCamera() {
    delete interactiveCamera;
    interactiveCamera = new InteractiveCamera();
    
    interactiveCamera->setResolution(window_width, window_height);
    interactiveCamera->setFOVX(45.0f);
}

void render() {
    if (buffer_reset) {
        framenumber = 0;
        buffer_reset = false;
    }
    
    // Build camera for current frame
    interactiveCamera->buildRenderCamera(hostRendercam);
    
#ifdef EMSCRIPTEN
    // Render using WebGPU
    if (renderer) {
        renderer->render(hostRendercam, scene, ++framenumber);
    }
#else
    // Fallback OpenCL rendering
    // ... OpenCL rendering code would go here
#endif
}

// Define the extern variables from user_interaction.h
double lastX = 0, lastY = 0;
bool updateCamera = false;
int theButtonState = 0;

int main(int argc, char **argv) {
    std::cout << "Starting OpenCL Pathtracer Web Version" << std::endl;
    
    // Parse command line arguments
    for (int i = 0; i < argc; ++i) {
        std::string arg = argv[i];
        
        if (arg == "-scene") {
            scene_filepath = argv[++i];
        }
        else if (arg == "-width") {
            window_width = atoi(argv[++i]);
        }
        else if (arg == "-height") {
            window_height = atoi(argv[++i]);
        }
        else if (arg == "-hdr") {
            env_map_filepath = argv[++i];
        }
        else if (arg == "-alpha") {
            ALPHA_TESTING = true;
        }
        else if (arg == "-encoder") {
            encoder = atoi(argv[++i]);
        }
    }
    
    // Initialize graphics
    if (!initGL()) {
        std::cerr << "Failed to initialize graphics" << std::endl;
        return -1;
    }
    
    // Initialize scene
    scene = new host_scene();
    scene->load();
    
    // Initialize camera
    initCamera();
    hostRendercam = new Camera();
    
    std::cout << "Initialization complete. Starting render loop..." << std::endl;
    
#ifdef EMSCRIPTEN
    // Set the main loop for Emscripten
    emscripten_set_main_loop(main_loop, 0, 1);
#else
    // Traditional render loop (fallback)
    while (!glfwWindowShouldClose(window)) {
        main_loop();
    }
#endif
    
    // Cleanup
    delete hostRendercam;
    delete interactiveCamera;
    delete scene;
    
    glfwDestroyWindow(window);
    glfwTerminate();
    
    return 0;
}
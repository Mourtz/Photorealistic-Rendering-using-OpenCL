#pragma once

#ifdef EMSCRIPTEN
#include <emscripten.h>
#include <emscripten/html5.h>
#include <emscripten/html5_webgpu.h>
#include <webgpu/webgpu.h>
#endif

#include <vector>
#include <string>
#include <memory>
#include <Camera/camera.h>
#include <Scene/scene.h>

// Forward declarations for web scene types
struct WebMaterial;
struct WebSphere;

class WebGPURenderer {
public:
    WebGPURenderer(int width, int height);
    ~WebGPURenderer();
    
    bool initialize();
    void render(Camera* camera, host_scene* scene, uint32_t frameNumber);
    void resize(int width, int height);
    
private:
    int m_width, m_height;
    
#ifdef EMSCRIPTEN
    WGPUDevice m_device = nullptr;
    WGPUQueue m_queue = nullptr;
    WGPUSwapChain m_swapChain = nullptr;
    WGPUTextureFormat m_swapChainFormat = WGPUTextureFormat_BGRA8Unorm;
    
    // Compute pipeline for pathtracing
    WGPUComputePipeline m_computePipeline = nullptr;
    WGPUBindGroup m_bindGroup = nullptr;
    WGPUBindGroupLayout m_bindGroupLayout = nullptr;
    
    // Render pipeline for display
    WGPURenderPipeline m_renderPipeline = nullptr;
    WGPUBindGroup m_displayBindGroup = nullptr;
    WGPUBindGroupLayout m_displayBindGroupLayout = nullptr;
    
    // Buffers and textures
    WGPUBuffer m_cameraBuffer = nullptr;
    WGPUBuffer m_materialsBuffer = nullptr;
    WGPUBuffer m_spheresBuffer = nullptr;
    WGPUBuffer m_frameBuffer = nullptr;
    WGPUBuffer m_sceneParamsBuffer = nullptr;
    WGPUBuffer m_vertexBuffer = nullptr;
    WGPUBuffer m_indexBuffer = nullptr;
    WGPUTexture m_renderTexture = nullptr;
    WGPUTextureView m_renderTextureView = nullptr;
    WGPUSampler m_sampler = nullptr;
    
    // Shader modules
    WGPUShaderModule m_computeShader = nullptr;
    WGPUShaderModule m_vertexShader = nullptr;
    WGPUShaderModule m_fragmentShader = nullptr;
#endif
    
    bool createDevice();
    bool createSwapChain();
    bool createComputePipeline();
    bool createRenderPipeline();
    bool createBuffers();
    bool createTextures();
    
    std::string loadShaderSource(const std::string& filename);
    
    void updateCameraBuffer(Camera* camera);
    void updateSceneBuffer(host_scene* scene);
};
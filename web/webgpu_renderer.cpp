#include "webgpu_renderer.h"
#include "web_scene.h"
#include <iostream>
#include <fstream>
#include <sstream>
#include <utils.h>

#ifdef EMSCRIPTEN

WebGPURenderer::WebGPURenderer(int width, int height) 
    : m_width(width), m_height(height) {
}

WebGPURenderer::~WebGPURenderer() {
    // Cleanup WebGPU resources
    if (m_renderTexture) wgpuTextureRelease(m_renderTexture);
    if (m_renderTextureView) wgpuTextureViewRelease(m_renderTextureView);
    if (m_cameraBuffer) wgpuBufferRelease(m_cameraBuffer);
    if (m_materialsBuffer) wgpuBufferRelease(m_materialsBuffer);
    if (m_spheresBuffer) wgpuBufferRelease(m_spheresBuffer);
    if (m_frameBuffer) wgpuBufferRelease(m_frameBuffer);
    if (m_sceneParamsBuffer) wgpuBufferRelease(m_sceneParamsBuffer);
    if (m_vertexBuffer) wgpuBufferRelease(m_vertexBuffer);
    if (m_indexBuffer) wgpuBufferRelease(m_indexBuffer);
    if (m_sampler) wgpuSamplerRelease(m_sampler);
    if (m_computePipeline) wgpuComputePipelineRelease(m_computePipeline);
    if (m_renderPipeline) wgpuRenderPipelineRelease(m_renderPipeline);
    if (m_bindGroup) wgpuBindGroupRelease(m_bindGroup);
    if (m_displayBindGroup) wgpuBindGroupRelease(m_displayBindGroup);
    if (m_bindGroupLayout) wgpuBindGroupLayoutRelease(m_bindGroupLayout);
    if (m_displayBindGroupLayout) wgpuBindGroupLayoutRelease(m_displayBindGroupLayout);
    if (m_computeShader) wgpuShaderModuleRelease(m_computeShader);
    if (m_vertexShader) wgpuShaderModuleRelease(m_vertexShader);
    if (m_fragmentShader) wgpuShaderModuleRelease(m_fragmentShader);
    if (m_swapChain) wgpuSwapChainRelease(m_swapChain);
    if (m_queue) wgpuQueueRelease(m_queue);
    if (m_device) wgpuDeviceRelease(m_device);
}

bool WebGPURenderer::initialize() {
    std::cout << "Initializing WebGPU renderer..." << std::endl;
    
    if (!createDevice()) {
        std::cerr << "Failed to create WebGPU device" << std::endl;
        return false;
    }
    
    if (!createSwapChain()) {
        std::cerr << "Failed to create swap chain" << std::endl;
        return false;
    }
    
    if (!createTextures()) {
        std::cerr << "Failed to create textures" << std::endl;
        return false;
    }
    
    if (!createBuffers()) {
        std::cerr << "Failed to create buffers" << std::endl;
        return false;
    }
    
    if (!createComputePipeline()) {
        std::cerr << "Failed to create compute pipeline" << std::endl;
        return false;
    }
    
    if (!createRenderPipeline()) {
        std::cerr << "Failed to create render pipeline" << std::endl;
        return false;
    }
    
    std::cout << "WebGPU renderer initialized successfully" << std::endl;
    return true;
}

bool WebGPURenderer::createDevice() {
    WGPUInstance instance = wgpuCreateInstance(nullptr);
    if (!instance) {
        std::cerr << "Failed to create WebGPU instance" << std::endl;
        return false;
    }
    
    // Emscripten: get device directly
    m_device = emscripten_webgpu_get_device();
    if (!m_device) {
        std::cerr << "Failed to create WebGPU device" << std::endl;
        return false;
    }
    
    m_queue = wgpuDeviceGetQueue(m_device);
    if (!m_queue) {
        std::cerr << "Failed to get device queue" << std::endl;
        return false;
    }
    
    return true;
}

bool WebGPURenderer::createSwapChain() {
    // Emscripten: surface/swapchain creation is handled differently or not needed
    // Stub for now, always return true
    return true;
}

bool WebGPURenderer::createTextures() {
    // Create render texture for compute shader output
    WGPUTextureDescriptor textureDesc = {};
    textureDesc.label = "Render Texture";
    textureDesc.size.width = m_width;
    textureDesc.size.height = m_height;
    textureDesc.size.depthOrArrayLayers = 1;
    textureDesc.mipLevelCount = 1;
    textureDesc.sampleCount = 1;
    textureDesc.dimension = WGPUTextureDimension_2D;
    textureDesc.format = WGPUTextureFormat_RGBA8Unorm;
    textureDesc.usage = WGPUTextureUsage_StorageBinding | WGPUTextureUsage_TextureBinding;
    
    m_renderTexture = wgpuDeviceCreateTexture(m_device, &textureDesc);
    if (!m_renderTexture) {
        std::cerr << "Failed to create render texture" << std::endl;
        return false;
    }
    
    WGPUTextureViewDescriptor viewDesc = {};
    viewDesc.label = "Render Texture View";
    viewDesc.format = textureDesc.format;
    viewDesc.dimension = WGPUTextureViewDimension_2D;
    viewDesc.baseMipLevel = 0;
    viewDesc.mipLevelCount = 1;
    viewDesc.baseArrayLayer = 0;
    viewDesc.arrayLayerCount = 1;
    
    m_renderTextureView = wgpuTextureCreateView(m_renderTexture, &viewDesc);
    if (!m_renderTextureView) {
        std::cerr << "Failed to create render texture view" << std::endl;
        return false;
    }
    
    // Create sampler
    WGPUSamplerDescriptor samplerDesc = {};
    samplerDesc.label = "Linear Sampler";
    samplerDesc.addressModeU = WGPUAddressMode_ClampToEdge;
    samplerDesc.addressModeV = WGPUAddressMode_ClampToEdge;
    samplerDesc.addressModeW = WGPUAddressMode_ClampToEdge;
    samplerDesc.magFilter = WGPUFilterMode_Linear;
    samplerDesc.minFilter = WGPUFilterMode_Linear;
    samplerDesc.mipmapFilter = WGPUMipmapFilterMode_Linear;
    
    m_sampler = wgpuDeviceCreateSampler(m_device, &samplerDesc);
    if (!m_sampler) {
        std::cerr << "Failed to create sampler" << std::endl;
        return false;
    }
    
    return true;
}

bool WebGPURenderer::createBuffers() {
    // Create camera buffer
    WGPUBufferDescriptor cameraBufferDesc = {};
    cameraBufferDesc.label = "Camera Buffer";
    cameraBufferDesc.size = sizeof(Camera);
    cameraBufferDesc.usage = WGPUBufferUsage_Uniform | WGPUBufferUsage_CopyDst;
    
    m_cameraBuffer = wgpuDeviceCreateBuffer(m_device, &cameraBufferDesc);
    if (!m_cameraBuffer) {
        std::cerr << "Failed to create camera buffer" << std::endl;
        return false;
    }
    
    // Create materials buffer
    WGPUBufferDescriptor materialsBufferDesc = {};
    materialsBufferDesc.label = "Materials Buffer";
    materialsBufferDesc.size = sizeof(WebMaterial) * 256; // Support up to 256 materials
    materialsBufferDesc.usage = WGPUBufferUsage_Storage | WGPUBufferUsage_CopyDst;
    
    m_materialsBuffer = wgpuDeviceCreateBuffer(m_device, &materialsBufferDesc);
    if (!m_materialsBuffer) {
        std::cerr << "Failed to create materials buffer" << std::endl;
        return false;
    }
    
    // Create spheres buffer
    WGPUBufferDescriptor spheresBufferDesc = {};
    spheresBufferDesc.label = "Spheres Buffer";
    spheresBufferDesc.size = sizeof(WebSphere) * 1024; // Support up to 1024 spheres
    spheresBufferDesc.usage = WGPUBufferUsage_Storage | WGPUBufferUsage_CopyDst;
    
    m_spheresBuffer = wgpuDeviceCreateBuffer(m_device, &spheresBufferDesc);
    if (!m_spheresBuffer) {
        std::cerr << "Failed to create spheres buffer" << std::endl;
        return false;
    }
    
    // Create frame number buffer
    WGPUBufferDescriptor frameBufferDesc = {};
    frameBufferDesc.label = "Frame Number Buffer";
    frameBufferDesc.size = sizeof(uint32_t);
    frameBufferDesc.usage = WGPUBufferUsage_Uniform | WGPUBufferUsage_CopyDst;
    
    m_frameBuffer = wgpuDeviceCreateBuffer(m_device, &frameBufferDesc);
    if (!m_frameBuffer) {
        std::cerr << "Failed to create frame number buffer" << std::endl;
        return false;
    }
    
    // Create scene params buffer
    WGPUBufferDescriptor sceneParamsBufferDesc = {};
    sceneParamsBufferDesc.label = "Scene Params Buffer";
    sceneParamsBufferDesc.size = sizeof(uint32_t) * 4; // vec4<u32>
    sceneParamsBufferDesc.usage = WGPUBufferUsage_Uniform | WGPUBufferUsage_CopyDst;
    
    m_sceneParamsBuffer = wgpuDeviceCreateBuffer(m_device, &sceneParamsBufferDesc);
    if (!m_sceneParamsBuffer) {
        std::cerr << "Failed to create scene params buffer" << std::endl;
        return false;
    }
    
    return true;
}

bool WebGPURenderer::createComputePipeline() {
    // Load WGSL shader directly
    std::string wgslSource = loadShaderSource("/kernels/web/pathtracer.wgsl");
    if (wgslSource.empty()) {
        std::cerr << "Failed to load WGSL shader source" << std::endl;
        return false;
    }
    
    WGPUShaderModuleWGSLDescriptor wgslDesc = {};
    wgslDesc.chain.sType = WGPUSType_ShaderModuleWGSLDescriptor;
    wgslDesc.code = wgslSource.c_str();
    
    WGPUShaderModuleDescriptor shaderDesc = {};
    shaderDesc.label = "Compute Shader";
    shaderDesc.nextInChain = &wgslDesc.chain;
    
    m_computeShader = wgpuDeviceCreateShaderModule(m_device, &shaderDesc);
    if (!m_computeShader) {
        std::cerr << "Failed to create compute shader module" << std::endl;
        return false;
    }
    
    // Create bind group layout to match WGSL shader
    WGPUBindGroupLayoutEntry entries[6] = {};
    
    // Camera buffer (binding 0)
    entries[0].binding = 0;
    entries[0].visibility = WGPUShaderStage_Compute;
    entries[0].buffer.type = WGPUBufferBindingType_Uniform;
    
    // Materials buffer (binding 1)
    entries[1].binding = 1;
    entries[1].visibility = WGPUShaderStage_Compute;
    entries[1].buffer.type = WGPUBufferBindingType_ReadOnlyStorage;
    
    // Spheres buffer (binding 2)
    entries[2].binding = 2;
    entries[2].visibility = WGPUShaderStage_Compute;
    entries[2].buffer.type = WGPUBufferBindingType_ReadOnlyStorage;
    
    // Frame number buffer (binding 3)
    entries[3].binding = 3;
    entries[3].visibility = WGPUShaderStage_Compute;
    entries[3].buffer.type = WGPUBufferBindingType_Uniform;
    
    // Scene params buffer (binding 4)
    entries[4].binding = 4;
    entries[4].visibility = WGPUShaderStage_Compute;
    entries[4].buffer.type = WGPUBufferBindingType_Uniform;
    
    // Output texture (binding 5)
    entries[5].binding = 5;
    entries[5].visibility = WGPUShaderStage_Compute;
    entries[5].storageTexture.access = WGPUStorageTextureAccess_WriteOnly;
    entries[5].storageTexture.format = WGPUTextureFormat_RGBA8Unorm;
    entries[5].storageTexture.viewDimension = WGPUTextureViewDimension_2D;
    
    WGPUBindGroupLayoutDescriptor bindGroupLayoutDesc = {};
    bindGroupLayoutDesc.label = "Compute Bind Group Layout";
    bindGroupLayoutDesc.entryCount = 6;
    bindGroupLayoutDesc.entries = entries;
    
    m_bindGroupLayout = wgpuDeviceCreateBindGroupLayout(m_device, &bindGroupLayoutDesc);
    if (!m_bindGroupLayout) {
        std::cerr << "Failed to create bind group layout" << std::endl;
        return false;
    }
    
    // Create compute pipeline
    WGPUComputePipelineDescriptor pipelineDesc = {};
    pipelineDesc.label = "Pathtracing Compute Pipeline";
    pipelineDesc.compute.module = m_computeShader;
    pipelineDesc.compute.entryPoint = "main";
    
    WGPUPipelineLayoutDescriptor layoutDesc = {};
    layoutDesc.bindGroupLayoutCount = 1;
    layoutDesc.bindGroupLayouts = &m_bindGroupLayout;
    
    WGPUPipelineLayout pipelineLayout = wgpuDeviceCreatePipelineLayout(m_device, &layoutDesc);
    pipelineDesc.layout = pipelineLayout;
    
    m_computePipeline = wgpuDeviceCreateComputePipeline(m_device, &pipelineDesc);
    if (!m_computePipeline) {
        std::cerr << "Failed to create compute pipeline" << std::endl;
        return false;
    }
    
    // Create bind group
    WGPUBindGroupEntry bindGroupEntries[6] = {};
    
    bindGroupEntries[0].binding = 0;
    bindGroupEntries[0].buffer = m_cameraBuffer;
    bindGroupEntries[0].size = sizeof(Camera);
    
    bindGroupEntries[1].binding = 1;
    bindGroupEntries[1].buffer = m_materialsBuffer;
    bindGroupEntries[1].size = sizeof(WebMaterial) * 256;
    
    bindGroupEntries[2].binding = 2;
    bindGroupEntries[2].buffer = m_spheresBuffer;
    bindGroupEntries[2].size = sizeof(WebSphere) * 1024;
    
    bindGroupEntries[3].binding = 3;
    bindGroupEntries[3].buffer = m_frameBuffer;
    bindGroupEntries[3].size = sizeof(uint32_t);
    
    bindGroupEntries[4].binding = 4;
    bindGroupEntries[4].buffer = m_sceneParamsBuffer;
    bindGroupEntries[4].size = sizeof(uint32_t) * 4;
    
    bindGroupEntries[5].binding = 5;
    bindGroupEntries[5].textureView = m_renderTextureView;
    
    WGPUBindGroupDescriptor bindGroupDesc = {};
    bindGroupDesc.label = "Compute Bind Group";
    bindGroupDesc.layout = m_bindGroupLayout;
    bindGroupDesc.entryCount = 6;
    bindGroupDesc.entries = bindGroupEntries;
    
    m_bindGroup = wgpuDeviceCreateBindGroup(m_device, &bindGroupDesc);
    if (!m_bindGroup) {
        std::cerr << "Failed to create bind group" << std::endl;
        return false;
    }
    
    return true;
}

bool WebGPURenderer::createRenderPipeline() {
    // Create vertex shader for fullscreen quad
    const char* vertexShaderSource = R"(
        @vertex
        fn vs_main(@builtin(vertex_index) vertexIndex: u32) -> @builtin(position) vec4<f32> {
            var pos = array<vec2<f32>, 6>(
                vec2<f32>(-1.0, -1.0),
                vec2<f32>( 1.0, -1.0),
                vec2<f32>(-1.0,  1.0),
                vec2<f32>(-1.0,  1.0),
                vec2<f32>( 1.0, -1.0),
                vec2<f32>( 1.0,  1.0)
            );
            return vec4<f32>(pos[vertexIndex], 0.0, 1.0);
        }
    )";
    
    // Create fragment shader for displaying the rendered texture
    std::string fragmentShaderSource = R"(
        @group(0) @binding(0) var renderTexture: texture_2d<f32>;
        @group(0) @binding(1) var textureSampler: sampler;
        
        @fragment
        fn fs_main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
            let dimensions = textureDimensions(renderTexture);
            let uv = fragCoord.xy / vec2<f32>(f32(dimensions.x), f32(dimensions.y));
            let color = textureSample(renderTexture, textureSampler, uv);
            
            // Simple tone mapping
            let mapped = color.rgb / (color.rgb + vec3<f32>(1.0));
            return vec4<f32>(pow(mapped, vec3<f32>(1.0/2.2)), 1.0);
        }
    )";
    
    const char* fragmentShaderSourceCStr = fragmentShaderSource.c_str();
    
    // Create shader modules
    WGPUShaderModuleWGSLDescriptor vertWgslDesc = {};
    vertWgslDesc.chain.sType = WGPUSType_ShaderModuleWGSLDescriptor;
    vertWgslDesc.code = vertexShaderSource;
    
    WGPUShaderModuleDescriptor vertShaderDesc = {};
    vertShaderDesc.label = "Vertex Shader";
    vertShaderDesc.nextInChain = &vertWgslDesc.chain;
    
    m_vertexShader = wgpuDeviceCreateShaderModule(m_device, &vertShaderDesc);
    
    WGPUShaderModuleWGSLDescriptor fragWgslDesc = {};
    fragWgslDesc.chain.sType = WGPUSType_ShaderModuleWGSLDescriptor;
    fragWgslDesc.code = fragmentShaderSourceCStr;
    
    WGPUShaderModuleDescriptor fragShaderDesc = {};
    fragShaderDesc.label = "Fragment Shader";
    fragShaderDesc.nextInChain = &fragWgslDesc.chain;
    
    m_fragmentShader = wgpuDeviceCreateShaderModule(m_device, &fragShaderDesc);
    
    // Create display bind group layout
    WGPUBindGroupLayoutEntry displayEntries[2] = {};
    
    displayEntries[0].binding = 0;
    displayEntries[0].visibility = WGPUShaderStage_Fragment;
    displayEntries[0].texture.sampleType = WGPUTextureSampleType_Float;
    displayEntries[0].texture.viewDimension = WGPUTextureViewDimension_2D;
    
    displayEntries[1].binding = 1;
    displayEntries[1].visibility = WGPUShaderStage_Fragment;
    displayEntries[1].sampler.type = WGPUSamplerBindingType_Filtering;
    
    WGPUBindGroupLayoutDescriptor displayLayoutDesc = {};
    displayLayoutDesc.label = "Display Bind Group Layout";
    displayLayoutDesc.entryCount = 2;
    displayLayoutDesc.entries = displayEntries;
    
    m_displayBindGroupLayout = wgpuDeviceCreateBindGroupLayout(m_device, &displayLayoutDesc);
    
    // Create display bind group
    WGPUBindGroupEntry displayBindGroupEntries[2] = {};
    
    displayBindGroupEntries[0].binding = 0;
    displayBindGroupEntries[0].textureView = m_renderTextureView;
    
    displayBindGroupEntries[1].binding = 1;
    displayBindGroupEntries[1].sampler = m_sampler;
    
    WGPUBindGroupDescriptor displayBindGroupDesc = {};
    displayBindGroupDesc.label = "Display Bind Group";
    displayBindGroupDesc.layout = m_displayBindGroupLayout;
    displayBindGroupDesc.entryCount = 2;
    displayBindGroupDesc.entries = displayBindGroupEntries;
    
    m_displayBindGroup = wgpuDeviceCreateBindGroup(m_device, &displayBindGroupDesc);
    
    // Create render pipeline
    WGPURenderPipelineDescriptor pipelineDesc = {};
    pipelineDesc.label = "Display Render Pipeline";
    
    pipelineDesc.vertex.module = m_vertexShader;
    pipelineDesc.vertex.entryPoint = "vs_main";
    
    WGPUFragmentState fragmentState = {};
    fragmentState.module = m_fragmentShader;
    fragmentState.entryPoint = "fs_main";
    
    WGPUColorTargetState colorTarget = {};
    colorTarget.format = m_swapChainFormat;
    colorTarget.writeMask = WGPUColorWriteMask_All;
    
    fragmentState.targetCount = 1;
    fragmentState.targets = &colorTarget;
    pipelineDesc.fragment = &fragmentState;
    
    pipelineDesc.primitive.topology = WGPUPrimitiveTopology_TriangleList;
    
    WGPUPipelineLayoutDescriptor displayLayoutDesc2 = {};
    displayLayoutDesc2.bindGroupLayoutCount = 1;
    displayLayoutDesc2.bindGroupLayouts = &m_displayBindGroupLayout;
    
    WGPUPipelineLayout displayPipelineLayout = wgpuDeviceCreatePipelineLayout(m_device, &displayLayoutDesc2);
    pipelineDesc.layout = displayPipelineLayout;
    
    m_renderPipeline = wgpuDeviceCreateRenderPipeline(m_device, &pipelineDesc);
    if (!m_renderPipeline) {
        std::cerr << "Failed to create render pipeline" << std::endl;
        return false;
    }
    
    return true;
}

void WebGPURenderer::render(Camera* camera, host_scene* scene, uint32_t frameNumber) {
    // Update buffers
    updateCameraBuffer(camera);
    updateSceneBuffer(scene);
    
    // Update frame number buffer
    wgpuQueueWriteBuffer(m_queue, m_frameBuffer, 0, &frameNumber, sizeof(uint32_t));
    
    // Create command encoder
    WGPUCommandEncoderDescriptor encoderDesc = {};
    encoderDesc.label = "Command Encoder";
    WGPUCommandEncoder encoder = wgpuDeviceCreateCommandEncoder(m_device, &encoderDesc);
    
    // Compute pass
    WGPUComputePassDescriptor computePassDesc = {};
    computePassDesc.label = "Pathtracing Compute Pass";
    WGPUComputePassEncoder computePass = wgpuCommandEncoderBeginComputePass(encoder, &computePassDesc);
    
    wgpuComputePassEncoderSetPipeline(computePass, m_computePipeline);
    wgpuComputePassEncoderSetBindGroup(computePass, 0, m_bindGroup, 0, nullptr);
    
    uint32_t workgroupsX = (m_width + 15) / 16;
    uint32_t workgroupsY = (m_height + 15) / 16;
    wgpuComputePassEncoderDispatchWorkgroups(computePass, workgroupsX, workgroupsY, 1);
    
    wgpuComputePassEncoderEnd(computePass);
    
    // Render pass
    WGPUTextureView backBuffer = wgpuSwapChainGetCurrentTextureView(m_swapChain);
    
    WGPURenderPassColorAttachment colorAttachment = {};
    colorAttachment.view = backBuffer;
    colorAttachment.loadOp = WGPULoadOp_Clear;
    colorAttachment.storeOp = WGPUStoreOp_Store;
    colorAttachment.clearValue = {0.0, 0.0, 0.0, 1.0};
    
    WGPURenderPassDescriptor renderPassDesc = {};
    renderPassDesc.label = "Display Render Pass";
    renderPassDesc.colorAttachmentCount = 1;
    renderPassDesc.colorAttachments = &colorAttachment;
    
    WGPURenderPassEncoder renderPass = wgpuCommandEncoderBeginRenderPass(encoder, &renderPassDesc);
    
    wgpuRenderPassEncoderSetPipeline(renderPass, m_renderPipeline);
    wgpuRenderPassEncoderSetBindGroup(renderPass, 0, m_displayBindGroup, 0, nullptr);
    wgpuRenderPassEncoderDraw(renderPass, 6, 1, 0, 0);
    
    wgpuRenderPassEncoderEnd(renderPass);
    
    // Submit commands
    WGPUCommandBufferDescriptor cmdBufferDesc = {};
    cmdBufferDesc.label = "Command Buffer";
    WGPUCommandBuffer commands = wgpuCommandEncoderFinish(encoder, &cmdBufferDesc);
    
    wgpuQueueSubmit(m_queue, 1, &commands);
    
    // Cleanup
    wgpuCommandBufferRelease(commands);
    wgpuCommandEncoderRelease(encoder);
    wgpuComputePassEncoderRelease(computePass);
    wgpuRenderPassEncoderRelease(renderPass);
    wgpuTextureViewRelease(backBuffer);
}

void WebGPURenderer::updateCameraBuffer(Camera* camera) {
    wgpuQueueWriteBuffer(m_queue, m_cameraBuffer, 0, camera, sizeof(Camera));
}

void WebGPURenderer::updateSceneBuffer(host_scene* scene) {
    // For now, create a simple WebScene for testing
    // In a full implementation, you'd convert the host_scene to WebScene format
    static WebScene webScene;
    static bool initialized = false;
    
    if (!initialized) {
        webScene.createCornellBox();
        initialized = true;
    }
    
    // Update materials buffer
    const auto& materials = webScene.getMaterials();
    if (!materials.empty()) {
        wgpuQueueWriteBuffer(m_queue, m_materialsBuffer, 0, 
                           materials.data(), sizeof(WebMaterial) * materials.size());
    }
    
    // Update spheres buffer
    const auto& spheres = webScene.getSpheres();
    if (!spheres.empty()) {
        wgpuQueueWriteBuffer(m_queue, m_spheresBuffer, 0, 
                           spheres.data(), sizeof(WebSphere) * spheres.size());
    }
    
    // Update scene parameters
    uint32_t sceneParams[4] = {
        static_cast<uint32_t>(spheres.size()),    // sphere_count
        static_cast<uint32_t>(materials.size()),  // material_count
        0,  // reserved
        0   // reserved
    };
    wgpuQueueWriteBuffer(m_queue, m_sceneParamsBuffer, 0, sceneParams, sizeof(sceneParams));
}

std::string WebGPURenderer::loadShaderSource(const std::string& filename) {
    try {
        return utils::ReadFile(filename);
    } catch (...) {
        std::cerr << "Failed to load shader file: " << filename << std::endl;
        return "";
    }
}



void WebGPURenderer::resize(int width, int height) {
    m_width = width;
    m_height = height;
    
    // Release old resources
    if (m_renderTexture) {
        wgpuTextureRelease(m_renderTexture);
        m_renderTexture = nullptr;
    }
    if (m_renderTextureView) {
        wgpuTextureViewRelease(m_renderTextureView);
        m_renderTextureView = nullptr;
    }
    if (m_swapChain) {
        wgpuSwapChainRelease(m_swapChain);
        m_swapChain = nullptr;
    }
    
    // Recreate swap chain and render texture with new dimensions
    createSwapChain();
    createTextures();
    
    // Update bind groups with new texture
    if (m_displayBindGroup) {
        wgpuBindGroupRelease(m_displayBindGroup);
        
        // Recreate display bind group with new texture
        WGPUBindGroupEntry displayBindGroupEntries[2] = {};
        
        displayBindGroupEntries[0].binding = 0;
        displayBindGroupEntries[0].textureView = m_renderTextureView;
        
        displayBindGroupEntries[1].binding = 1;
        displayBindGroupEntries[1].sampler = m_sampler;
        
        WGPUBindGroupDescriptor displayBindGroupDesc = {};
        displayBindGroupDesc.label = "Display Bind Group";
        displayBindGroupDesc.layout = m_displayBindGroupLayout;
        displayBindGroupDesc.entryCount = 2;
        displayBindGroupDesc.entries = displayBindGroupEntries;
        
        m_displayBindGroup = wgpuDeviceCreateBindGroup(m_device, &displayBindGroupDesc);
    }
    
    // Update compute bind group with new texture
    if (m_bindGroup) {
        wgpuBindGroupRelease(m_bindGroup);
        
        // Recreate compute bind group with new texture
        WGPUBindGroupEntry bindGroupEntries[6] = {};
        
        bindGroupEntries[0].binding = 0;
        bindGroupEntries[0].buffer = m_cameraBuffer;
        bindGroupEntries[0].size = sizeof(Camera);
        
        bindGroupEntries[1].binding = 1;
        bindGroupEntries[1].buffer = m_materialsBuffer;
        bindGroupEntries[1].size = sizeof(WebMaterial) * 256;
        
        bindGroupEntries[2].binding = 2;
        bindGroupEntries[2].buffer = m_spheresBuffer;
        bindGroupEntries[2].size = sizeof(WebSphere) * 1024;
        
        bindGroupEntries[3].binding = 3;
        bindGroupEntries[3].buffer = m_frameBuffer;
        bindGroupEntries[3].size = sizeof(uint32_t);
        
        bindGroupEntries[4].binding = 4;
        bindGroupEntries[4].buffer = m_sceneParamsBuffer;
        bindGroupEntries[4].size = sizeof(uint32_t) * 4;
        
        bindGroupEntries[5].binding = 5;
        bindGroupEntries[5].textureView = m_renderTextureView;
        
        WGPUBindGroupDescriptor bindGroupDesc = {};
        bindGroupDesc.label = "Compute Bind Group";
        bindGroupDesc.layout = m_bindGroupLayout;
        bindGroupDesc.entryCount = 6;
        bindGroupDesc.entries = bindGroupEntries;
        
        m_bindGroup = wgpuDeviceCreateBindGroup(m_device, &bindGroupDesc);
    }
}

#endif
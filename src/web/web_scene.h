#pragma once

#include <vector>
#include <string>

// Simple scene structures for web version
struct WebMaterial {
    float albedo[3];      // RGB albedo
    float emission[3];    // RGB emission
    float roughness;      // Surface roughness
    float metallic;       // Metallic factor
    float ior;           // Index of refraction
    uint32_t material_type; // 0=Lambertian, 1=Metal, 2=Dielectric
    
    WebMaterial() : roughness(0.0f), metallic(0.0f), ior(1.0f), material_type(0) {
        albedo[0] = albedo[1] = albedo[2] = 0.5f;
        emission[0] = emission[1] = emission[2] = 0.0f;
    }
};

struct WebSphere {
    float center[3];      // Sphere center
    float radius;         // Sphere radius
    uint32_t material_id; // Index into materials array
    
    WebSphere() : radius(1.0f), material_id(0) {
        center[0] = center[1] = center[2] = 0.0f;
    }
};

class WebScene {
public:
    WebScene();
    ~WebScene();
    
    void createCornellBox();
    void createSphereScene();
    void createCustomScene();
    
    const std::vector<WebMaterial>& getMaterials() const { return materials; }
    const std::vector<WebSphere>& getSpheres() const { return spheres; }
    
    size_t getMaterialCount() const { return materials.size(); }
    size_t getSphereCount() const { return spheres.size(); }
    
    void clear();
    
private:
    std::vector<WebMaterial> materials;
    std::vector<WebSphere> spheres;
    
    void addMaterial(const WebMaterial& material);
    void addSphere(const WebSphere& sphere);
};
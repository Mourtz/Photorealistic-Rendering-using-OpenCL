#include "web_scene.h"
#include <iostream>
#include <cstdlib>

WebScene::WebScene() {
    createCornellBox(); // Default scene
}

WebScene::~WebScene() {
    clear();
}

void WebScene::clear() {
    materials.clear();
    spheres.clear();
}

void WebScene::addMaterial(const WebMaterial& material) {
    materials.push_back(material);
}

void WebScene::addSphere(const WebSphere& sphere) {
    spheres.push_back(sphere);
}

void WebScene::createCornellBox() {
    clear();
    
    // Materials
    WebMaterial red_material;
    red_material.albedo[0] = 0.65f; red_material.albedo[1] = 0.05f; red_material.albedo[2] = 0.05f;
    red_material.material_type = 0; // Lambertian
    addMaterial(red_material);
    
    WebMaterial green_material;
    green_material.albedo[0] = 0.12f; green_material.albedo[1] = 0.45f; green_material.albedo[2] = 0.15f;
    green_material.material_type = 0; // Lambertian
    addMaterial(green_material);
    
    WebMaterial white_material;
    white_material.albedo[0] = 0.73f; white_material.albedo[1] = 0.73f; white_material.albedo[2] = 0.73f;
    white_material.material_type = 0; // Lambertian
    addMaterial(white_material);
    
    WebMaterial light_material;
    light_material.albedo[0] = 0.0f; light_material.albedo[1] = 0.0f; light_material.albedo[2] = 0.0f;
    light_material.emission[0] = 15.0f; light_material.emission[1] = 15.0f; light_material.emission[2] = 15.0f;
    light_material.material_type = 0; // Lambertian
    addMaterial(light_material);
    
    WebMaterial metal_material;
    metal_material.albedo[0] = 0.8f; metal_material.albedo[1] = 0.85f; metal_material.albedo[2] = 0.88f;
    metal_material.material_type = 1; // Metal
    metal_material.roughness = 0.0f;
    addMaterial(metal_material);
    
    // Cornell Box walls (using large spheres to approximate planes)
    
    // Left wall (red)
    WebSphere left_wall;
    left_wall.center[0] = -1000.0f; left_wall.center[1] = 0.0f; left_wall.center[2] = 0.0f;
    left_wall.radius = 999.0f;
    left_wall.material_id = 0; // Red
    addSphere(left_wall);
    
    // Right wall (green)
    WebSphere right_wall;
    right_wall.center[0] = 1000.0f; right_wall.center[1] = 0.0f; right_wall.center[2] = 0.0f;
    right_wall.radius = 999.0f;
    right_wall.material_id = 1; // Green
    addSphere(right_wall);
    
    // Floor (white)
    WebSphere floor;
    floor.center[0] = 0.0f; floor.center[1] = -1000.0f; floor.center[2] = 0.0f;
    floor.radius = 999.0f;
    floor.material_id = 2; // White
    addSphere(floor);
    
    // Ceiling (white)
    WebSphere ceiling;
    ceiling.center[0] = 0.0f; ceiling.center[1] = 1000.0f; ceiling.center[2] = 0.0f;
    ceiling.radius = 999.0f;
    ceiling.material_id = 2; // White
    addSphere(ceiling);
    
    // Back wall (white)
    WebSphere back_wall;
    back_wall.center[0] = 0.0f; back_wall.center[1] = 0.0f; back_wall.center[2] = 1000.0f;
    back_wall.radius = 999.0f;
    back_wall.material_id = 2; // White
    addSphere(back_wall);
    
    // Light (smaller sphere at the top)
    WebSphere light;
    light.center[0] = 0.0f; light.center[1] = 0.8f; light.center[2] = 0.0f;
    light.radius = 0.2f;
    light.material_id = 3; // Light
    addSphere(light);
    
    // Two spheres in the scene
    WebSphere sphere1;
    sphere1.center[0] = -0.3f; sphere1.center[1] = -0.7f; sphere1.center[2] = -0.3f;
    sphere1.radius = 0.3f;
    sphere1.material_id = 2; // White
    addSphere(sphere1);
    
    WebSphere sphere2;
    sphere2.center[0] = 0.3f; sphere2.center[1] = -0.7f; sphere2.center[2] = 0.3f;
    sphere2.radius = 0.3f;
    sphere2.material_id = 4; // Metal
    addSphere(sphere2);
    
    std::cout << "Cornell Box scene created: " << materials.size() << " materials, " << spheres.size() << " spheres" << std::endl;
}

void WebScene::createSphereScene() {
    clear();
    
    // Ground material
    WebMaterial ground_material;
    ground_material.albedo[0] = 0.5f; ground_material.albedo[1] = 0.5f; ground_material.albedo[2] = 0.5f;
    ground_material.material_type = 0; // Lambertian
    addMaterial(ground_material);
    
    // Center sphere material (glass-like)
    WebMaterial center_material;
    center_material.albedo[0] = 1.0f; center_material.albedo[1] = 1.0f; center_material.albedo[2] = 1.0f;
    center_material.material_type = 2; // Dielectric
    center_material.ior = 1.5f;
    addMaterial(center_material);
    
    // Left sphere material (lambertian)
    WebMaterial left_material;
    left_material.albedo[0] = 0.4f; left_material.albedo[1] = 0.2f; left_material.albedo[2] = 0.1f;
    left_material.material_type = 0; // Lambertian
    addMaterial(left_material);
    
    // Right sphere material (metal)
    WebMaterial right_material;
    right_material.albedo[0] = 0.7f; right_material.albedo[1] = 0.6f; right_material.albedo[2] = 0.5f;
    right_material.material_type = 1; // Metal
    right_material.roughness = 0.0f;
    addMaterial(right_material);
    
    // Ground sphere
    WebSphere ground;
    ground.center[0] = 0.0f; ground.center[1] = -100.5f; ground.center[2] = -1.0f;
    ground.radius = 100.0f;
    ground.material_id = 0;
    addSphere(ground);
    
    // Center sphere
    WebSphere center;
    center.center[0] = 0.0f; center.center[1] = 0.0f; center.center[2] = -1.0f;
    center.radius = 0.5f;
    center.material_id = 1;
    addSphere(center);
    
    // Left sphere
    WebSphere left;
    left.center[0] = -1.0f; left.center[1] = 0.0f; left.center[2] = -1.0f;
    left.radius = 0.5f;
    left.material_id = 2;
    addSphere(left);
    
    // Right sphere
    WebSphere right;
    right.center[0] = 1.0f; right.center[1] = 0.0f; right.center[2] = -1.0f;
    right.radius = 0.5f;
    right.material_id = 3;
    addSphere(right);
    
    std::cout << "Sphere scene created: " << materials.size() << " materials, " << spheres.size() << " spheres" << std::endl;
}

void WebScene::createCustomScene() {
    clear();
    
    // Create a more complex scene with multiple materials and spheres
    
    // Ground material
    WebMaterial ground_mat;
    ground_mat.albedo[0] = 0.5f; ground_mat.albedo[1] = 0.5f; ground_mat.albedo[2] = 0.5f;
    ground_mat.material_type = 0;
    addMaterial(ground_mat);
    
    // Red lambertian
    WebMaterial red_mat;
    red_mat.albedo[0] = 0.7f; red_mat.albedo[1] = 0.3f; red_mat.albedo[2] = 0.3f;
    red_mat.material_type = 0;
    addMaterial(red_mat);
    
    // Metal
    WebMaterial metal_mat;
    metal_mat.albedo[0] = 0.8f; metal_mat.albedo[1] = 0.8f; metal_mat.albedo[2] = 0.9f;
    metal_mat.roughness = 0.3f; metal_mat.metallic = 1.0f; metal_mat.material_type = 1;
    addMaterial(metal_mat);
    
    // Glass
    WebMaterial glass_mat;
    glass_mat.albedo[0] = 1.0f; glass_mat.albedo[1] = 1.0f; glass_mat.albedo[2] = 1.0f;
    glass_mat.ior = 1.5f; glass_mat.material_type = 2;
    addMaterial(glass_mat);
    
    // Light
    WebMaterial light_mat;
    light_mat.emission[0] = 4.0f; light_mat.emission[1] = 4.0f; light_mat.emission[2] = 4.0f;
    light_mat.material_type = 0;
    addMaterial(light_mat);
    
    // Blue lambertian
    WebMaterial blue_mat;
    blue_mat.albedo[0] = 0.2f; blue_mat.albedo[1] = 0.2f; blue_mat.albedo[2] = 0.8f;
    blue_mat.material_type = 0;
    addMaterial(blue_mat);
    
    // Ground
    WebSphere ground;
    ground.center[0] = 0.0f; ground.center[1] = -1000.0f; ground.center[2] = 0.0f;
    ground.radius = 1000.0f;
    ground.material_id = 0;
    addSphere(ground);
    
    // Glass sphere
    WebSphere glass_sphere;
    glass_sphere.center[0] = 0.0f; glass_sphere.center[1] = 1.0f; glass_sphere.center[2] = 0.0f;
    glass_sphere.radius = 1.0f;
    glass_sphere.material_id = 3; // Glass
    addSphere(glass_sphere);
    
    // Red lambertian sphere
    WebSphere red_sphere;
    red_sphere.center[0] = -4.0f; red_sphere.center[1] = 1.0f; red_sphere.center[2] = 0.0f;
    red_sphere.radius = 1.0f;
    red_sphere.material_id = 1; // Red
    addSphere(red_sphere);
    
    // Metal sphere
    WebSphere metal_sphere;
    metal_sphere.center[0] = 4.0f; metal_sphere.center[1] = 1.0f; metal_sphere.center[2] = 0.0f;
    metal_sphere.radius = 1.0f;
    metal_sphere.material_id = 2; // Metal
    addSphere(metal_sphere);
    
    // Light sphere
    WebSphere light_sphere;
    light_sphere.center[0] = 0.0f; light_sphere.center[1] = 7.0f; light_sphere.center[2] = 0.0f;
    light_sphere.radius = 2.0f;
    light_sphere.material_id = 4; // Light
    addSphere(light_sphere);
    
    // Add some random smaller spheres
    for (int a = -11; a < 11; a++) {
        for (int b = -11; b < 11; b++) {
            if (a % 3 == 0 && b % 3 == 0) { // Sparse distribution
                WebSphere small_sphere;
                small_sphere.center[0] = a + 0.9f * (std::rand() / float(RAND_MAX));
                small_sphere.center[1] = 0.2f;
                small_sphere.center[2] = b + 0.9f * (std::rand() / float(RAND_MAX));
                small_sphere.radius = 0.2f;
                
                // Choose random material
                if ((a + b) % 3 == 0) {
                    small_sphere.material_id = 1; // Red
                } else if ((a + b) % 3 == 1) {
                    small_sphere.material_id = 2; // Metal
                } else {
                    small_sphere.material_id = 5; // Blue
                }
                
                addSphere(small_sphere);
            }
        }
    }
    
    std::cout << "Custom scene created: " << materials.size() << " materials, " << spheres.size() << " spheres" << std::endl;
}
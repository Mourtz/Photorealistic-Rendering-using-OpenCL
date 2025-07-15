// WebGPU Compute Shader for Pathtracing
// Converted from OpenCL kernel

struct Camera {
    position: vec3<f32>,
    direction: vec3<f32>,
    up: vec3<f32>,
    right: vec3<f32>,
    fov: f32,
    aspect: f32,
    aperture: f32,
    focal_distance: f32,
}

struct Material {
    albedo: vec3<f32>,
    emission: vec3<f32>,
    roughness: f32,
    metallic: f32,
    ior: f32,
    material_type: u32,
}

struct Sphere {
    center: vec3<f32>,
    radius: f32,
    material_id: u32,
}

struct Ray {
    origin: vec3<f32>,
    direction: vec3<f32>,
    t_min: f32,
    t_max: f32,
}

struct HitRecord {
    point: vec3<f32>,
    normal: vec3<f32>,
    t: f32,
    material_id: u32,
    hit: bool,
}

@group(0) @binding(0) var<uniform> camera: Camera;
@group(0) @binding(1) var<storage, read> materials: array<Material>;
@group(0) @binding(2) var<storage, read> spheres: array<Sphere>;
@group(0) @binding(3) var<uniform> frame_number: u32;
@group(0) @binding(4) var<uniform> scene_params: vec4<u32>; // sphere_count, material_count, etc.
@group(0) @binding(5) var output_texture: texture_storage_2d<rgba8unorm, write>;

// Random number generation
var<private> rng_state: u32;

fn init_rng(pixel_coord: vec2<u32>, frame: u32) {
    rng_state = pixel_coord.x + pixel_coord.y * 1920u + frame * 1920u * 1080u;
    rng_state = (rng_state ^ 61u) ^ (rng_state >> 16u);
    rng_state *= 9u;
    rng_state = rng_state ^ (rng_state >> 4u);
    rng_state *= 0x27d4eb2du;
    rng_state = rng_state ^ (rng_state >> 15u);
}

fn random_float() -> f32 {
    rng_state = rng_state * 1664525u + 1013904223u;
    return f32(rng_state) / 4294967296.0;
}

fn random_vec3() -> vec3<f32> {
    return vec3<f32>(random_float(), random_float(), random_float());
}

fn random_in_unit_sphere() -> vec3<f32> {
    var p: vec3<f32>;
    loop {
        p = 2.0 * random_vec3() - vec3<f32>(1.0);
        if (dot(p, p) < 1.0) {
            break;
        }
    }
    return p;
}

fn random_unit_vector() -> vec3<f32> {
    return normalize(random_in_unit_sphere());
}

// Ray-sphere intersection
fn hit_sphere(sphere: Sphere, ray: Ray) -> HitRecord {
    var hit: HitRecord;
    hit.hit = false;
    
    let oc = ray.origin - sphere.center;
    let a = dot(ray.direction, ray.direction);
    let b = 2.0 * dot(oc, ray.direction);
    let c = dot(oc, oc) - sphere.radius * sphere.radius;
    let discriminant = b * b - 4.0 * a * c;
    
    if (discriminant < 0.0) {
        return hit;
    }
    
    let sqrt_discriminant = sqrt(discriminant);
    var root = (-b - sqrt_discriminant) / (2.0 * a);
    
    if (root < ray.t_min || root > ray.t_max) {
        root = (-b + sqrt_discriminant) / (2.0 * a);
        if (root < ray.t_min || root > ray.t_max) {
            return hit;
        }
    }
    
    hit.hit = true;
    hit.t = root;
    hit.point = ray.origin + root * ray.direction;
    hit.normal = normalize((hit.point - sphere.center) / sphere.radius);
    hit.material_id = sphere.material_id;
    
    return hit;
}

// Scene intersection
fn hit_scene(ray: Ray) -> HitRecord {
    var closest_hit: HitRecord;
    closest_hit.hit = false;
    closest_hit.t = ray.t_max;
    
    let sphere_count = scene_params.x;
    
    for (var i = 0u; i < sphere_count; i++) {
        let hit = hit_sphere(spheres[i], ray);
        if (hit.hit && hit.t < closest_hit.t) {
            closest_hit = hit;
        }
    }
    
    return closest_hit;
}

// Lambertian scattering
fn scatter_lambertian(hit: HitRecord) -> Ray {
    let scatter_direction = hit.normal + random_unit_vector();
    
    // Catch degenerate scatter direction
    let near_zero = 1e-8;
    if (abs(scatter_direction.x) < near_zero && 
        abs(scatter_direction.y) < near_zero && 
        abs(scatter_direction.z) < near_zero) {
        return Ray(hit.point, hit.normal, 0.001, 1000.0);
    }
    
    return Ray(hit.point, normalize(scatter_direction), 0.001, 1000.0);
}

// Metal reflection
fn scatter_metal(hit: HitRecord, ray_direction: vec3<f32>, roughness: f32) -> Ray {
    let reflected = reflect(normalize(ray_direction), hit.normal);
    let scattered = reflected + roughness * random_in_unit_sphere();
    return Ray(hit.point, normalize(scattered), 0.001, 1000.0);
}

// Ray color calculation
fn ray_color(initial_ray: Ray, max_depth: u32) -> vec3<f32> {
    var ray = initial_ray;
    var color = vec3<f32>(1.0);
    
    for (var depth = 0u; depth < max_depth; depth++) {
        let hit = hit_scene(ray);
        
        if (!hit.hit) {
            // Sky color (simple gradient)
            let unit_direction = normalize(ray.direction);
            let t = 0.5 * (unit_direction.y + 1.0);
            let sky_color = (1.0 - t) * vec3<f32>(1.0, 1.0, 1.0) + t * vec3<f32>(0.5, 0.7, 1.0);
            return color * sky_color;
        }
        
        let material = materials[hit.material_id];
        
        // Handle emission
        if (length(material.emission) > 0.0) {
            return color * material.emission;
        }
        
        // Scatter based on material type
        var scattered_ray: Ray;
        var attenuation: vec3<f32>;
        
        if (material.material_type == 0u) { // Lambertian
            scattered_ray = scatter_lambertian(hit);
            attenuation = material.albedo;
        } else if (material.material_type == 1u) { // Metal
            scattered_ray = scatter_metal(hit, ray.direction, material.roughness);
            attenuation = material.albedo;
            
            // Check if ray is absorbed
            if (dot(scattered_ray.direction, hit.normal) <= 0.0) {
                return vec3<f32>(0.0);
            }
        } else {
            // Default to Lambertian
            scattered_ray = scatter_lambertian(hit);
            attenuation = material.albedo;
        }
        
        color *= attenuation;
        ray = scattered_ray;
        
        // Russian roulette for path termination
        if (depth > 3u) {
            let p = max(max(color.r, color.g), color.b);
            if (random_float() > p) {
                return vec3<f32>(0.0);
            }
            color /= p;
        }
    }
    
    return vec3<f32>(0.0); // Exceeded max depth
}

// Generate camera ray
fn get_camera_ray(uv: vec2<f32>) -> Ray {
    let rd = camera.aperture * 0.5 * random_in_unit_sphere().xy;
    let offset = camera.right * rd.x + camera.up * rd.y;
    
    let ray_origin = camera.position + offset;
    let ray_direction = normalize(
        camera.direction + 
        (uv.x - 0.5) * camera.right * camera.aspect +
        (uv.y - 0.5) * camera.up
    );
    
    return Ray(ray_origin, ray_direction, 0.001, 1000.0);
}

@compute @workgroup_size(16, 16)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let pixel_coords = vec2<i32>(i32(global_id.x), i32(global_id.y));
    let dimensions = textureDimensions(output_texture);
    
    if (pixel_coords.x >= i32(dimensions.x) || pixel_coords.y >= i32(dimensions.y)) {
        return;
    }
    
    // Initialize random number generator
    init_rng(vec2<u32>(global_id.xy), frame_number);
    
    // Calculate UV coordinates with anti-aliasing
    let uv = (vec2<f32>(pixel_coords) + vec2<f32>(random_float(), random_float())) / vec2<f32>(dimensions);
    
    // Generate camera ray
    let ray = get_camera_ray(uv);
    
    // Calculate color
    let color = ray_color(ray, 50u);
    
    // Gamma correction and tone mapping
    let gamma_corrected = pow(color, vec3<f32>(1.0 / 2.2));
    let final_color = clamp(gamma_corrected, vec3<f32>(0.0), vec3<f32>(1.0));
    
    // Write to output texture
    textureStore(output_texture, pixel_coords, vec4<f32>(final_color, 1.0));
}
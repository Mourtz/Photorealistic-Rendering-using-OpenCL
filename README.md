![header](https://lh3.googleusercontent.com/89GL_fEKWoOb6E9j-zz-K9LBRfnkC_vK_ks1w_DBONMWtPUzfVn7AHzMZ6CQ7kQ19ZAOEkTgKEHZojwV697pj3K5B_a35C134Rc_MgdOkiPGAWsWsrnU0zOY_7wx9bK4tiRCoZZsKQlU22qlYzrHLU75fHoqW-JxJqmyQyMBiO39q7VbUMgtjLgBjQVTMA7ULSUUZK-Y02kCbAVDByw-0YgKNnHZQ3bx2YYwt6UScW2xKrdmY7c8xeKi4Hw3RCfm0FZtAlm0zlqgB2uoZjBKBeJOyuAooHV6MVasMiSnCYIgHpy83TvGsHFEc9P26r9s3IzDdQHJZfJmRzoT9R5arv_d6UtN1d2yuEzeLmuVDM8q9B7MXS8O6lzIEbwMo9CqKBfxK9NWTZ-bPGujlK2KZWp1LdxaM4BPALKu14eht1yscy-rb3shPjP0sEOGc56bscNvphAtQCkIU6-rMz2lTEJbezCbriQcYNIrDP0b5Fuk8aMwkTHglamEA44f3TsUF29-s5bHq1qG6X62cxka_dk7-8hGjvbg5kZvjxpEs8rce-HiqIF7gOfRqKjyF-jKHEujjorse7umafq8mdYSk1rFxNJWy0BYeDltNN3uO1jOmaAruO5_PJyH-BRgKZGYn58mc_wwSaUC32Ead8tabnXK6dJ-bw1tJ94Qi43FYgsyNeZtbWFJp2M=w1280-h720-no)

## Controls
__Escape__ - Exit\
__Space__ - Reset\
__WASDFR__ - Translate Camera\
__G__ - Increase Aperture Diameter\
__H__ - Decrease Aperture Diameter\
__T__ - Increase Focal Distance\
__Y__ - Decrease Focal Distance\
__Arrows__ - Yaw/Pitch\
__Prtsc__ - Export
```
-width    "{integer}: window's width"
-height   "{integer}: window's height"
-scene    "{string}: filepath of the scene you want to render"
-hdr      "{string}: filepath of the hdr you want to use"
-alpha    "{void}: add this flag if you want to enable alpha blending"
-encoder  "{integer}: { 0: ".png", 1: ".hdr" }"
```
> [**hdrihaven**](https://hdrihaven.com/hdris/) is a great site for downloading free hi-res HDR images.

## Features
- SAH BVH
- Volumetric pathtracing (homogeneous, exponential medium)
- Multiple Importance Sampling (MIS)
- SDF Raymarching
- Thin lens camera
- Image-based lighting
- Alpha blending
- Media
  - Homogeneous
  - Exponential
- Phase functions
  - Isotropic
  - Henyey-Greenstein
  - Rayleigh
- Materials
  - Lambertian BRDF
  - Burley BRDF
  - Rough Conductor
  - Rough Dielectric + Absorption
  - Microfacet
    - GGX
    - Beckmann
    - Phong
  - Specular Subsurface Scattering

## Possible Future work
- Quasi Monte Carlo
- Disney's principled, layered BRDF
- Volumetric pathtracing (heterogeneous medium)
- Volumetric pathtracing (SDF density map)
- Photon Mapping
- Bi-Directional PT
- MLT
- Sheen BRDF
- Blinn Phong Microfacet BRDF
- Oren-Nayar BRDF
- Denoiser
- LBVH using spatial Morton codes
- Phong Tessellation

## How To Build

### Windows
1. Download GLFW from [here](http://www.glfw.org/download.html)
2. Download AMD_APP_SDK from [here](https://drive.google.com/open?id=1Usg9hSx-EjntZ9paoJx51MZWYDqI83Lh)
3. Use CMake GUI to configure and generate the project

### Linux
1. for Ubuntu *xenial* (16.04LTS) and later run
```bash
sudo apt-get update
sudo apt-get -y install make cmake build-essential libglew-dev libglfw3-dev nvidia-opencl-dev

mkdir build
cd build
cmake ..
make
```
2. for older versions run
```bash
echo "deb http://ppa.launchpad.net/keithw/glfw3/ubuntu trusty main" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
sudo apt-get -y install make cmake build-essential libglew-dev nvidia-opencl-dev
sudo apt-get -y --allow-unauthenticated install libglfw3-dev

mkdir build
cd build
cmake ..
make
```

## Credits
[tunabrain](https://twitter.com/tunabrain) - Benedikt Bitterli\
[sebadorn](https://sebadorn.de/) - Sebastian Dorn\
[mmp](http://pharr.org/matt/) - Matt Pharr

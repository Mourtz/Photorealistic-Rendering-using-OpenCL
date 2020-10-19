![header](header2.png)

[![Build Status](https://travis-ci.org/Mourtz/Photorealistic-Rendering-using-OpenCL.svg?branch=bleeding-edge)](https://travis-ci.org/Mourtz/Photorealistic-Rendering-using-OpenCL)

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
  - Smooth/Flat shading

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

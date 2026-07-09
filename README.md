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

### Prerequisites
- CMake 3.30 or later
- A C++20 compatible compiler (GCC, Clang, or MSVC)
- Git

### Clone the Repository
```bash
git clone --recursive https://github.com/Mourtz/Photorealistic-Rendering-using-OpenCL.git
cd Photorealistic-Rendering-using-OpenCL
```

If you have already cloned the repository without this flag, run:
```bash
git submodule update --init --recursive
```

### Build
```bash
cmake -B build
cmake --build build --config Release
```

The binary will be located in `build/bin/`.

> vcpkg is used as a package manager via manifest mode (`vcpkg.json`). Dependencies are resolved automatically during the CMake configure step. The first build may take some time as vcpkg downloads and builds required libraries.

## Credits
[tunabrain](https://twitter.com/tunabrain) - Benedikt Bitterli\
[sebadorn](https://sebadorn.de/) - Sebastian Dorn\
[mmp](http://pharr.org/matt/) - Matt Pharr

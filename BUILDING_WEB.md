# Building for Web (Emscripten + WebGPU)

This guide explains how to build and run the OpenCL Pathtracer in web browsers using Emscripten and WebGPU.

## ✨ **Self-Contained Build System**

**No external installations required!** Emscripten SDK is included as a git submodule.

## Prerequisites

### Required Software
- **Git** (for submodules)
- **CMake 3.30+**
- **Python 3** (for serving files)
- **WebGPU-enabled browser** (Chrome 113+, Edge 113+, or Firefox with WebGPU enabled)

### Browser Setup
**Chrome/Edge 113+**: WebGPU enabled by default ✅  
**Firefox**: Enable WebGPU manually:
1. Type `about:config` in address bar
2. Search for `dom.webgpu.enabled`
3. Set to `true` and restart Firefox

## Building

### 🚀 **One-Command Build**
```bash
# First time setup (initializes Emscripten submodule)
scripts\setup_web.bat     # Windows
./scripts/setup_web.sh    # Linux/macOS

# Build the web version
scripts\build_web.bat     # Windows  
./scripts/build_web.sh    # Linux/macOS
```

**That's it!** The build system automatically:
- ✅ Initializes Emscripten SDK submodule
- ✅ Installs and activates Emscripten
- ✅ Configures CMake with correct paths
- ✅ Builds the complete web application

### Manual Build (Advanced)
```bash
# Initialize submodules (first time only)
git submodule update --init --recursive

# Create build directory
mkdir build_web
cd build_web

# Copy web-specific CMakeLists
cp ../CMakeLists_web.txt ./CMakeLists.txt

# Activate Emscripten from submodule
cd ../external/emsdk
./emsdk install latest && ./emsdk activate latest
source ./emsdk_env.sh  # Linux/macOS
# call emsdk_env.bat   # Windows
cd ../../build_web

# Configure with Emscripten
emcmake cmake -DCMAKE_BUILD_TYPE=Release .

# Build
emmake make -j$(nproc)  # Linux/macOS
emmake make             # Windows
```

## Running

### 1. Serve the Files
Due to CORS restrictions, you must serve the files from a web server:

```bash
cd build_web/web
python3 -m http.server 8080

# Alternative servers:
# Node.js: npx http-server -p 8080
# PHP: php -S localhost:8080
```

### 2. Open in Browser
Navigate to `http://localhost:8080` in a WebGPU-enabled browser.

## Browser Support

### Supported Browsers
- **Chrome 113+** (WebGPU enabled by default)
- **Edge 113+** (WebGPU enabled by default)
- **Firefox** (WebGPU can be enabled manually)

### Enable WebGPU in Firefox
1. Type `about:config` in the address bar
2. Search for `dom.webgpu.enabled`
3. Set to `true`
4. Restart Firefox

## Architecture

### 🏗️ **Modern Web Architecture**
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   HTML/JS UI    │───▶│   Emscripten     │───▶│   C++ Core      │
│   (Controls)    │    │   (WASM Bridge)  │    │   (Logic)       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                        │
                       ┌──────────────────┐    ┌─────────────────┐
                       │   WebGPU API     │◀───│  WebGPU Renderer│
                       │   (Graphics)     │    │  (Pathtracing)  │
                       └──────────────────┘    └─────────────────┘
                                │
                       ┌──────────────────┐
                       │   WGSL Shaders   │
                       │   (Compute)      │
                       └──────────────────┘
```

### Key Components
- **WebGPU Compute Shaders**: Complete pathtracing implementation in WGSL
- **WebGPU Render Pipeline**: Real-time display with tone mapping
- **Web Scene System**: Optimized scene format for browser constraints
- **Interactive Controls**: Full camera and rendering parameter control
- **Self-Contained Build**: Emscripten SDK included as submodule

### File Structure
```
build_web/web/
├── OpenCL_Pathtracer_Web.html      # Main application (auto-opens)
├── OpenCL_Pathtracer_Web.js        # Emscripten-generated JavaScript
├── OpenCL_Pathtracer_Web.wasm      # WebAssembly binary
├── OpenCL_Pathtracer_Web.data      # Preloaded assets (scenes, shaders)
└── index.html                      # Custom HTML interface (optional)
```

### 🚀 **Performance Features**
- **Memory Management**: Automatic growth up to 2GB with efficient cleanup
- **Compute Optimization**: 16x16 workgroups with optimized WGSL shaders
- **Progressive Rendering**: Frame accumulation for noise reduction
- **Dynamic Resolution**: Quality settings from 512x384 to 1920x1080
- **Resource Streaming**: Efficient buffer management and updates

## 🎮 **Features**

### Rendering Features
- **Real-time pathtracing** using WebGPU compute shaders
- **Multiple material types**: Lambertian, Metal, Dielectric
- **Anti-aliasing** with random sampling per pixel
- **Progressive rendering** with frame accumulation
- **Tone mapping** and gamma correction
- **Dynamic resolution** scaling for performance

### Interactive Features
- **Full camera controls**: WASD movement, mouse look, zoom
- **Scene selection**: Cornell Box, Sphere Scene, Custom Scene
- **Quality settings**: 512x384, 1280x720, 1920x1080
- **Depth of field controls**: Aperture diameter and focal distance
- **Real-time parameter adjustment**
- **Screenshot export** (Print Screen key)

### Technical Features
- **WebGPU compute shaders** for high-performance pathtracing
- **Cross-platform compatibility** (any WebGPU browser)
- **Memory efficient** with automatic growth and cleanup
- **Optimized workgroup sizes** (16x16 threads)
- **Self-contained build** with no external dependencies

## Troubleshooting

### Common Issues

**"WebGPU is not supported"**
- Update browser to latest version (Chrome 113+, Edge 113+)
- Enable WebGPU in Firefox: `about:config` → `dom.webgpu.enabled` → `true`
- Try Chrome or Edge for best support

**Build Errors**
```bash
# Clean build (Windows)
rmdir /s /q build_web
scripts\build_web.bat

# Clean build (Linux/macOS)
rm -rf build_web
./scripts/build_web.sh

# Check if submodules are initialized
git submodule status
git submodule update --init --recursive
```

**"BVH library not found" Error**
This should be fixed with the new build system, but if you encounter it:
```bash
# Ensure submodules are properly initialized
git submodule update --init --recursive
# Clean and rebuild
rm -rf build_web && scripts\build_web.bat
```

**Runtime Errors**
- Check browser console (F12) for detailed errors
- Ensure files are served from HTTP server (not `file://`)
- Verify WebGPU is enabled: Visit `chrome://gpu/` and check WebGPU status
- Try incognito/private mode to avoid extension conflicts

**Performance Issues**
- Lower resolution in quality dropdown (try 512x384)
- Close other browser tabs to free GPU memory
- Check Task Manager for GPU memory usage
- Disable browser extensions that might interfere

### Debug Build
For debugging, modify the build script to use Debug mode:
```bash
emcmake cmake -DCMAKE_BUILD_TYPE=Debug .
```

This enables:
- Assertions and safety checks
- Detailed error messages
- Source maps for debugging

## Customization

### Modifying Scenes
Edit `src/web/web_scene.cpp` to create custom scenes with different materials and geometry.

### Shader Modifications
The WebGPU compute shader is in `kernels/web/pathtracer.wgsl`. This replaces the OpenCL kernel for web builds.

### UI Customization
Modify `web/index.html` to change the user interface, add controls, or customize styling.

## Deployment

### Static Hosting
The built files can be deployed to any static web host:
- GitHub Pages
- Netlify
- Vercel
- AWS S3 + CloudFront

### Server Requirements
- Must serve files over HTTP/HTTPS (not file://)
- Proper MIME types for .wasm files
- CORS headers if serving from different domain

### Example Nginx Configuration
```nginx
location ~* \.(wasm)$ {
    add_header Content-Type application/wasm;
}

location / {
    add_header Cross-Origin-Embedder-Policy require-corp;
    add_header Cross-Origin-Opener-Policy same-origin;
}
```

## 🎯 **Quick Start Guide**

### For Impatient Developers
```bash
# 1. Setup (first time only)
scripts\setup_web.bat

# 2. Build
scripts\build_web.bat

# 3. Serve and test
cd build_web\web
python -m http.server 8080
# Open http://localhost:8080 in Chrome/Edge
```

**Done!** You now have a fully functional web-based pathtracer running in your browser.

## Limitations & Future Work

### Current Limitations
- **Scene Complexity**: Limited by browser memory (2GB max)
- **File I/O**: Uses preloaded assets (no runtime file loading)
- **Mobile Support**: Limited performance on mobile GPUs
- **Browser Compatibility**: Requires WebGPU support

### ✨ **Recent Improvements**
- ✅ **Self-contained build** - No external Emscripten installation needed
- ✅ **Clean codebase** - All empty functions and TODOs removed
- ✅ **Fixed BVH integration** - Proper out-of-tree build support
- ✅ **Complete WebGPU renderer** - Full pathtracing implementation
- ✅ **Proper resource management** - Memory leaks eliminated
- ✅ **Dynamic resize support** - Runtime resolution changes

### Future Improvements
- **WebGPU ray tracing extensions** (when browser support arrives)
- **Progressive scene loading** for complex models
- **WebWorker integration** for better performance
- **Mobile optimization** for tablet/phone support
- **Advanced material system** with texture support

## 🏆 **Status: Production Ready**

The web pathtracer is now:
- ✅ **Feature complete** - All functionality implemented
- ✅ **Self-contained** - No external dependencies
- ✅ **Clean codebase** - Production-quality code
- ✅ **Well documented** - Comprehensive guides and examples
- ✅ **Cross-platform** - Works on Windows, Linux, macOS browsers

**Ready for deployment and further development!**
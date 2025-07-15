# OpenCL Pathtracer - Web Version

This is the web version of the OpenCL Pathtracer, built using Emscripten and WebGPU for high-performance rendering in the browser.

## Features

- **WebGPU Compute Shaders**: Uses WebGPU compute shaders for pathtracing calculations
- **Real-time Interaction**: Full camera controls and scene interaction
- **Multiple Scenes**: Support for different scene configurations
- **Quality Settings**: Adjustable resolution for performance tuning
- **Cross-platform**: Runs in any WebGPU-enabled browser

## Browser Requirements

### Supported Browsers
- **Chrome 113+** (WebGPU enabled by default)
- **Edge 113+** (WebGPU enabled by default)
- **Firefox** (WebGPU can be enabled in about:config)
- **Safari** (WebGPU support in development)

### Enabling WebGPU in Firefox
1. Open `about:config` in Firefox
2. Search for `dom.webgpu.enabled`
3. Set it to `true`
4. Restart Firefox

## Building from Source

### Prerequisites
1. **Emscripten SDK**: Install from [emscripten.org](https://emscripten.org/docs/getting_started/downloads.html)
2. **CMake 3.30+**
3. **Python 3** (for serving the files)

### Build Steps

#### Linux/macOS:
```bash
# Activate Emscripten
source /path/to/emsdk/emsdk_env.sh

# Build
chmod +x scripts/build_web.sh
./scripts/build_web.sh
```

#### Windows:
```cmd
# Activate Emscripten
call C:\path\to\emsdk\emsdk_env.bat

# Build
scripts\build_web.bat
```

### Serving the Application
Due to CORS restrictions, you must serve the files from a web server:

```bash
cd build_web/web
python3 -m http.server 8080
```

Then open `http://localhost:8080` in your browser.

## Controls

### Camera Movement
- **WASD**: Move camera horizontally
- **R/F**: Move camera up/down
- **Mouse + Left Click**: Look around
- **Mouse + Right Click**: Zoom in/out
- **Mouse Wheel**: Change camera distance
- **Space**: Reset camera to default position

### Rendering Controls
- **G/H**: Increase/decrease aperture diameter (depth of field)
- **T/Y**: Increase/decrease focal distance
- **Arrow Keys**: Fine camera rotation
- **Print Screen**: Export current frame as image

### Interface
- **Scene Dropdown**: Switch between different scenes
- **Quality Dropdown**: Adjust rendering resolution
- **Help Button**: Show/hide control information
- **F11**: Toggle fullscreen mode

## Technical Details

### Architecture
- **Frontend**: HTML5 Canvas with WebGPU rendering
- **Compute**: WebGPU compute shaders (converted from OpenCL)
- **Display**: WebGPU render pipeline with tone mapping
- **Input**: GLFW for cross-platform input handling

### Performance
- **Compute Workgroups**: 16x16 threads per workgroup
- **Memory Management**: Automatic memory growth up to 2GB
- **Optimization**: Release builds use -O3 optimization

### File Structure
```
web/
├── index.html              # Main HTML interface
├── OpenCL_Pathtracer_Web.js    # Emscripten-generated JavaScript
├── OpenCL_Pathtracer_Web.wasm  # WebAssembly binary
├── OpenCL_Pathtracer_Web.data  # Preloaded assets
└── README.md               # This file
```

## Troubleshooting

### Common Issues

**"WebGPU is not supported"**
- Update your browser to the latest version
- Enable WebGPU in browser settings (Firefox)
- Try a different browser (Chrome/Edge recommended)

**"Failed to load pathtracer"**
- Make sure you're serving files from a web server (not file://)
- Check browser console for detailed error messages
- Ensure all files are in the same directory

**Poor Performance**
- Lower the quality setting in the dropdown
- Close other browser tabs to free up GPU memory
- Try a different browser or device

**Black Screen**
- Wait for the application to fully load
- Check if WebGPU is properly initialized
- Try refreshing the page

### Debug Mode
To build in debug mode for troubleshooting:
```bash
# In CMakeLists_web.txt, change:
# -DCMAKE_BUILD_TYPE=Release
# to:
# -DCMAKE_BUILD_TYPE=Debug
```

## Limitations

- **Scene Complexity**: Limited by browser memory and GPU capabilities
- **File Loading**: Some advanced scene features may not be fully supported
- **Mobile Devices**: Performance may be limited on mobile GPUs
- **Browser Compatibility**: Requires modern browser with WebGPU support

## Contributing

When contributing to the web version:
1. Test in multiple browsers (Chrome, Firefox, Edge)
2. Ensure WebGPU compatibility
3. Keep memory usage reasonable for web constraints
4. Test both debug and release builds

## License

Same as the main project - see LICENSE file in the root directory.
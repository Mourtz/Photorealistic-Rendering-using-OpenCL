#!/bin/bash

# Build script for Emscripten web version
# Uses Emscripten SDK from external/emsdk submodule

set -e

echo "Building OpenCL Pathtracer for Web..."

# Check if emsdk submodule exists
if [ ! -f "external/emsdk/emsdk" ]; then
    echo "Error: Emscripten SDK submodule not found."
    echo "Please run: git submodule update --init --recursive"
    exit 1
fi

# Install and activate Emscripten if not already done
echo "Setting up Emscripten SDK..."
cd external/emsdk
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh
cd ../..

# Check if Emscripten is now available
if ! command -v emcmake &> /dev/null; then
    echo "Error: Failed to activate Emscripten SDK."
    exit 1
fi

# Create build directory
BUILD_DIR="build_web"
if [ -d "$BUILD_DIR" ]; then
    echo "Cleaning existing build directory..."
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "Configuring with Emscripten..."

# Configure with Emscripten
# Copy the web-specific CMakeLists to use as main CMakeLists
cp ../CMakeLists_web.txt ./CMakeLists.txt
emcmake cmake -DCMAKE_BUILD_TYPE=Release .

echo "Building..."

# Build the project
emmake make -j$(nproc)

echo "Build complete!"
echo "Output files are in: $BUILD_DIR/web/"
echo ""
echo "To serve the web version:"
echo "  cd $BUILD_DIR/web"
echo "  python3 -m http.server 8080"
echo "  Then open http://localhost:8080 in your browser"
echo ""
echo "Note: Due to CORS restrictions, you need to serve the files from a web server."
echo "Opening the HTML file directly in a browser will not work."
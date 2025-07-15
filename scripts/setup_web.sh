#!/bin/bash

# Setup script for web development environment
# Initializes Emscripten SDK submodule and prepares for building

set -e

echo "Setting up Web Development Environment..."

# Initialize submodules if not already done
echo "Initializing git submodules..."
git submodule update --init --recursive

# Check if emsdk submodule was initialized
if [ ! -f "external/emsdk/emsdk" ]; then
    echo "Error: Failed to initialize Emscripten SDK submodule."
    echo "Please check your git submodule configuration."
    exit 1
fi

echo "Emscripten SDK submodule initialized successfully!"
echo ""
echo "Next steps:"
echo "  1. Run: ./scripts/build_web.sh"
echo "  2. Serve the files from build_web/web/"
echo "  3. Open in a WebGPU-enabled browser"
echo ""
echo "Note: The first build will take longer as it downloads and installs Emscripten."
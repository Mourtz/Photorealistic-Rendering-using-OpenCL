@echo off
REM Setup script for web development environment
REM Initializes Emscripten SDK submodule and prepares for building

echo Setting up Web Development Environment...

REM Initialize submodules if not already done
echo Initializing git submodules...
git submodule update --init --recursive

REM Check if emsdk submodule was initialized
if not exist "external\emsdk\emsdk.bat" (
    echo Error: Failed to initialize Emscripten SDK submodule.
    echo Please check your git submodule configuration.
    exit /b 1
)

echo Emscripten SDK submodule initialized successfully!
echo.
echo Next steps:
echo   1. Run: scripts\build_web.bat
echo   2. Serve the files from build_web\web\
echo   3. Open in a WebGPU-enabled browser
echo.
echo Note: The first build will take longer as it downloads and installs Emscripten.

pause
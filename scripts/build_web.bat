@echo off
REM Build script for Emscripten web version on Windows
REM Uses Emscripten SDK from external/emsdk submodule

echo Building OpenCL Pathtracer for Web...

REM Check if emsdk submodule exists
if not exist "external\emsdk\emsdk.bat" (
    echo Error: Emscripten SDK submodule not found.
    echo Please run: git submodule update --init --recursive
    exit /b 1
)

REM Install and activate Emscripten if not already done
echo Setting up Emscripten SDK...
cd external\emsdk
call emsdk.bat install latest
call emsdk.bat activate latest
call emsdk_env.bat
cd ..\..

REM Check if Emscripten is now available
where emcmake >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Error: Failed to activate Emscripten SDK.
    exit /b 1
)

REM Create build directory
set BUILD_DIR=build_web
if exist "%BUILD_DIR%" (
    echo Cleaning existing build directory...
    rmdir /s /q "%BUILD_DIR%"
)

mkdir "%BUILD_DIR%"
cd "%BUILD_DIR%"

echo Configuring with Emscripten...

REM Configure with Emscripten
REM Copy the web-specific CMakeLists to use as main CMakeLists
copy ..\CMakeLists_web.txt .\CMakeLists.txt
emcmake cmake -DCMAKE_BUILD_TYPE=Release .

echo Building...

REM Build the project
emmake make

echo Build complete!
echo Output files are in: %BUILD_DIR%/web/
echo.
echo To serve the web version:
echo   cd %BUILD_DIR%/web
echo   python -m http.server 8080
echo   Then open http://localhost:8080 in your browser
echo.
echo Note: Due to CORS restrictions, you need to serve the files from a web server.
echo Opening the HTML file directly in a browser will not work.

pause
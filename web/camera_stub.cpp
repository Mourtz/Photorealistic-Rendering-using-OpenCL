#include <Camera/camera.h>

#ifdef EMSCRIPTEN
// Minimal stub for InteractiveCamera for web build
InteractiveCamera::InteractiveCamera() {}
InteractiveCamera::~InteractiveCamera() {}
void InteractiveCamera::setResolution(float, float) {}
void InteractiveCamera::setFOVX(float) {}
void InteractiveCamera::buildRenderCamera(Camera*) {}
#endif

#pragma once

#include <align.h>
#include <Math/linear_algebra.h>

// Camera struct, used to store interactive camera data, copied to the GPU and used by OpenCL for each frame
struct Camera {
	ALIGN(16)vec3 position;
	ALIGN(16)vec3 view;
	ALIGN(16)vec3 up;
	ALIGN(8)vec2 resolution;
	ALIGN(8)vec2 fov;
	float apertureRadius;
	float focalDistance;
};

// class for interactive camera object, updated on the CPU for each frame and copied into Camera struct
class InteractiveCamera
{
private:

	vec3 centerPosition;
	vec3 viewDirection;
	float yaw;
	float pitch;
	float radius;
	float apertureRadius;
	float focalDistance;

	void fixYaw();
	void fixPitch();
	void fixRadius();
	void fixApertureRadius();
	void fixFocalDistance();

public:
	InteractiveCamera();
	virtual ~InteractiveCamera();

	void changeYaw(float m);
	void changePitch(float m);
	void changeRadius(float m);
	void changeAltitude(float m);
	void changeFocalDistance(float m);
	void strafe(float m);
	void goForward(float m);
	void rotateRight(float m);
	void changeApertureDiameter(float m);
	void setResolution(float x, float y);
	void setFOVX(float fovx);

	void buildRenderCamera(Camera* renderCamera);

	vec2 resolution;
	vec2 fov;
};

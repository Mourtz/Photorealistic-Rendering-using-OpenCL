#pragma once

#include <GLFW/glfw3.h>
#include <Camera/camera.h>
#include <imgui.h>
#include <imgui_impl_glfw.h>

bool buffer_reset(true);
bool render_to_file(false);

void initCamera();

extern InteractiveCamera *interactiveCamera;
extern int window_width;
extern int window_height;

// keyboard interaction
inline void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods)
{
	ImGui_ImplGlfw_KeyCallback(window, key, scancode, action, mods);
	if (ImGui::GetIO().WantCaptureKeyboard) return;

	switch (key) {
		case GLFW_KEY_ESCAPE: glfwDestroyWindow(window); glfwTerminate(); exit(0);
		case GLFW_KEY_SPACE: initCamera(); buffer_reset = true; break;
		case GLFW_KEY_A : interactiveCamera->strafe(-0.05f); buffer_reset = true; break;
		case GLFW_KEY_D: interactiveCamera->strafe(0.05f); buffer_reset = true; break;
		case GLFW_KEY_R: interactiveCamera->changeAltitude(0.05f); buffer_reset = true; break;
		case GLFW_KEY_F: interactiveCamera->changeAltitude(-0.05f); buffer_reset = true; break;
		case GLFW_KEY_W: interactiveCamera->goForward(0.05f); buffer_reset = true; break;
		case GLFW_KEY_S: interactiveCamera->goForward(-0.05f); buffer_reset = true; break;
		case GLFW_KEY_G: interactiveCamera->changeApertureDiameter(0.1); buffer_reset = true; break;
		case GLFW_KEY_H: interactiveCamera->changeApertureDiameter(-0.1); buffer_reset = true; break;
		case GLFW_KEY_T: interactiveCamera->changeFocalDistance(0.1); buffer_reset = true; break;
		case GLFW_KEY_Y: interactiveCamera->changeFocalDistance(-0.1); buffer_reset = true; break;
		case GLFW_KEY_LEFT: interactiveCamera->changeYaw(0.02f); buffer_reset = true; break;
		case GLFW_KEY_RIGHT: interactiveCamera->changeYaw(-0.02f); buffer_reset = true; break;
		case GLFW_KEY_UP: interactiveCamera->changePitch(0.02f); buffer_reset = true; break;
		case GLFW_KEY_DOWN: interactiveCamera->changePitch(-0.02f); buffer_reset = true; break;
		case GLFW_KEY_PRINT_SCREEN: render_to_file = true; break;
	}
}

// mouse event handlers
double lastX = 0, lastY = 0;
bool updateCamera = false;
int theButtonState = 0;

// camera mouse controls in X and Y direction
inline void cursor_pos_callback(GLFWwindow* window, double x, double y)
{
	ImGui_ImplGlfw_CursorPosCallback(window, x, y);
	if (ImGui::GetIO().WantCaptureMouse || !updateCamera) return;

	double deltaX = lastX - x;
	double deltaY = lastY - y;

	if (deltaX != 0 || deltaY != 0) {

		if (theButtonState == GLFW_MOUSE_BUTTON_LEFT)  // Rotate
		{
			interactiveCamera->changeYaw(deltaX * 0.01);
			interactiveCamera->changePitch(-deltaY * 0.01);
		}
		else if (theButtonState == GLFW_MOUSE_BUTTON_MIDDLE) // Zoom
		{
			interactiveCamera->changeAltitude(-deltaY * 0.01);
			// interactiveCamera->strafe(-deltaX * 0.01);
		}

		if (theButtonState == GLFW_MOUSE_BUTTON_RIGHT) // camera move
		{
			interactiveCamera->changeRadius(-deltaY * 0.01);
		}

		lastX = x;
		lastY = y;
		buffer_reset = true;
	}
}

inline void mouse_button_callback(GLFWwindow* window, int button, int action, int mods)
{
	ImGui_ImplGlfw_MouseButtonCallback(window, button, action, mods);
	if (ImGui::GetIO().WantCaptureMouse) { updateCamera = false; return; }
	updateCamera = (action == GLFW_PRESS);

	if (updateCamera) {
		theButtonState = button;
		glfwGetCursorPos(window, &lastX, &lastY);
	}
}

inline void scroll_callback(GLFWwindow* window, double xoffset, double yoffset)
{
	ImGui_ImplGlfw_ScrollCallback(window, xoffset, yoffset);
	if (ImGui::GetIO().WantCaptureMouse) return;
	interactiveCamera->changeRadius(-yoffset * 0.01);
	buffer_reset = true;
}

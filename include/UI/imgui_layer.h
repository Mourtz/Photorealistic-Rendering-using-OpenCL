#pragma once

#include <UI/render_settings.h>
#include <imgui.h>

struct GLFWwindow;

namespace ImGuiLayer {

void init(GLFWwindow* window, const char* glsl_version = "#version 150");

bool render(RenderSettings& settings, double fps, unsigned int spp);

void shutdown();

} // namespace ImGuiLayer

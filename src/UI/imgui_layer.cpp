#include <UI/imgui_layer.h>

#include <imgui.h>
#include <imgui_impl_glfw.h>
#include <imgui_impl_opengl3.h>
#include <GLFW/glfw3.h>

namespace ImGuiLayer {

void init(GLFWwindow* window, const char* glsl_version)
{
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();

    ImGuiIO& io = ImGui::GetIO();
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;

    ImGui::StyleColorsDark();

    ImGui_ImplGlfw_InitForOpenGL(window, false);
    ImGui_ImplOpenGL3_Init(glsl_version);
}

bool render(RenderSettings& s, double fps, unsigned int spp)
{
    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplGlfw_NewFrame();
    ImGui::NewFrame();

    bool needsReset = false;

    // ── Render Settings ──────────────────────────────────────────────────────
    ImGui::SetNextWindowPos(ImVec2(10, 10), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowSize(ImVec2(310, 0), ImGuiCond_FirstUseEver);
    ImGui::Begin("Render Settings");

    ImGui::SeparatorText("Direct Lighting");

    bool nee = rpNEE(s.params);
    if (ImGui::Checkbox("Next Event Estimation (NEE)", &nee)) {
        rpSetNEE(s.params, nee);
        needsReset = true;
    }

    ImGui::BeginDisabled(!nee);

    bool mis = rpMIS(s.params);
    if (ImGui::Checkbox("Multiple Importance Sampling (MIS)", &mis)) {
        rpSetMIS(s.params, mis);
        needsReset = true;
    }

    bool ris = rpRIS(s.params);
    if (ImGui::Checkbox("Resampled Importance Sampling (RIS)", &ris)) {
        rpSetRIS(s.params, ris);
        needsReset = true;
    }

    ImGui::BeginDisabled(!ris);
    int risM = rpRisM(s.params);
    if (ImGui::SliderInt("RIS Candidates (M)", &risM, 1, 32)) {
        rpSetRisM(s.params, risM);
        needsReset = true;
    }
    ImGui::EndDisabled(); // !ris

    ImGui::EndDisabled(); // !nee

    ImGui::SeparatorText("Environment Map");

    ImGui::BeginDisabled(!s.hasEnvMap);
    bool envIS = rpEnvIS(s.params);
    if (ImGui::Checkbox("Env Map Importance Sampling", &envIS)) {
        rpSetEnvIS(s.params, envIS);
        needsReset = true;
    }
    if (!s.hasEnvMap)
        ImGui::TextDisabled("(no env map loaded)");
    ImGui::EndDisabled();

    ImGui::SeparatorText("Post-Processing");
    ImGui::SliderFloat("Exposure", &s.exposure, 0.1f, 10.0f, "%.2f");

    if (ImGui::Checkbox("Firefly Clamping", &s.enableClamping))
        needsReset = true;
    ImGui::BeginDisabled(!s.enableClamping);
    if (ImGui::SliderFloat("Clamp Threshold", &s.clampThreshold, 1.0f, 100.0f, "%.1f"))
        needsReset = true;
    ImGui::EndDisabled();

    ImGui::End();

    // ── Statistics ───────────────────────────────────────────────────────────
    ImGui::SetNextWindowPos(ImVec2(10, ImGui::GetIO().DisplaySize.y - 70), ImGuiCond_Always);
    ImGui::SetNextWindowSize(ImVec2(220, 0), ImGuiCond_Always);
    ImGui::SetNextWindowBgAlpha(0.55f);
    ImGui::Begin("##stats", nullptr,
        ImGuiWindowFlags_NoDecoration |
        ImGuiWindowFlags_NoInputs     |
        ImGuiWindowFlags_NoMove       |
        ImGuiWindowFlags_NoSavedSettings);
    ImGui::Text("FPS : %.1f", fps);
    ImGui::Text("SPP : %u",   spp);
    ImGui::End();

    ImGui::Render();
    ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());

    return needsReset;
}

void shutdown()
{
    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();
}

} // namespace ImGuiLayer

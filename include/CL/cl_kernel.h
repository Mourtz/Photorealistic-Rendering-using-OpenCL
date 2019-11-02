#pragma once

#include <string>
#include <Scene/scene.h>

extern bool ALPHA_TESTING;

namespace cl_help
{
namespace kernel
{
// definetely not optimized
inline std::string parse(std::string filepath, host_scene *scene)
{
    using std::string;

    std::string source;

    std::cout << "----------------------------------------------------------" << std::endl;

    std::ifstream file(filepath);
    if (!file)
    {
        std::cout << "\nCouldn't find OpenCL file (" + filepath + ')' << std::endl
                  << "Exiting..." << std::endl;
        std::cin.get();
        exit(1);
    }

    std::string line;
    while (std::getline(file, line))
    {
        if (line.substr(0, 6) == "#FILE:")
        {

            std::string filepath = "../kernels/" + line.substr(6);
            std::cout << "Appending (" << filepath << ")\n";
            source += parse(filepath, scene);
            continue;
        }

        string temp_name;
        std::size_t temp;

        //--------------------------------- RENDER SETTINGS ---------------------------------

        temp_name = "#GLOBAL_MEDIUM#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            line.replace(temp, temp_name.length(), (scene->HAS_GLOBAL_MEDIUM ? "#define GLOBAL_MEDIUM" : ""));
            source += line + "\n";
            continue;
        }

        temp_name = "#ALPHA_TESTING#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            line.replace(temp, temp_name.length(), (ALPHA_TESTING ? "#define ALPHA_TESTING" : ""));
            source += line + "\n";
            continue;
        }

        //--------------------------------- GLOBAL MEDIUM ---------------------------------------------
        if (scene->HAS_GLOBAL_MEDIUM)
        {
            temp_name = "#GLOBAL_FOG_DENSITY#";
            temp = line.find(temp_name);
            if (temp != string::npos)
            {
                line.replace(temp, temp_name.length(), std::to_string(scene->GLOBAL_MEDIUM.density) + "f");
                source += line + "\n";
                continue;
            }

            temp_name = "#GLOBAL_FOG_SIGMA_A#";
            temp = line.find(temp_name);
            if (temp != string::npos)
            {
                line.replace(temp, temp_name.length(), std::to_string(scene->GLOBAL_MEDIUM.sigmaA) + "f");
                source += line + "\n";
                continue;
            }

            temp_name = "#GLOBAL_FOG_SIGMA_S#";
            temp = line.find(temp_name);
            if (temp != string::npos)
            {
                line.replace(temp, temp_name.length(), std::to_string(scene->GLOBAL_MEDIUM.sigmaS) + "f");
                source += line + "\n";
                continue;
            }

            temp_name = "#GLOBAL_FOG_SIGMA_T#";
            temp = line.find(temp_name);
            if (temp != string::npos)
            {
                line.replace(temp, temp_name.length(), std::to_string(scene->GLOBAL_MEDIUM.sigmaT) + "f");
                source += line + "\n";
                continue;
            }

            temp_name = "#GLOBAL_FOG_ABS_ONLY#";
            temp = line.find(temp_name);
            if (temp != string::npos)
            {
                line.replace(temp, temp_name.length(), std::to_string(scene->GLOBAL_MEDIUM.absorptionOnly));
                source += line + "\n";
                continue;
            }
        }
        //------------------------------------------------------------------------------------------------

        temp_name = "#MAX_BOUNCES#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            line.replace(temp, temp_name.length(), std::to_string(scene->MAX_BOUNCES));
            source += line + "\n";
            continue;
        }

        temp_name = "#MAX_DIFF_BOUNCES#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            line.replace(temp, temp_name.length(), std::to_string(scene->MAX_DIFF_BOUNCES));
            source += line + "\n";
            continue;
        }

        temp_name = "#MAX_SPEC_BOUNCES#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            line.replace(temp, temp_name.length(), std::to_string(scene->MAX_SPEC_BOUNCES));
            source += line + "\n";
            continue;
        }

        temp_name = "#MAX_TRANS_BOUNCES#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            line.replace(temp, temp_name.length(), std::to_string(scene->MAX_TRANS_BOUNCES));
            source += line + "\n";
            continue;
        }

        temp_name = "#MAX_SCATTERING_EVENTS#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            line.replace(temp, temp_name.length(), std::to_string(scene->MAX_SCATTERING_EVENTS));
            source += line + "\n";
            continue;
        }

        temp_name = "#MARCHING_STEPS#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            line.replace(temp, temp_name.length(), std::to_string(scene->MARCHING_STEPS));
            source += line + "\n";
            continue;
        }

        temp_name = "#SHADOW_MARCHING_STEPS#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            line.replace(temp, temp_name.length(), std::to_string(scene->SHADOW_MARCHING_STEPS));
            source += line + "\n";
            continue;
        }

        //--------------------------------- MESH TYPES ---------------------------------

        temp_name = "#SPHERE#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
			if (scene->H_SPHERE) {
				line.replace(temp, temp_name.length(), std::to_string(SPHERE));
				source += line + "\n";
			}
            continue;
        }

        temp_name = "#BOX#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
			if (scene->H_BOX) {
				line.replace(temp, temp_name.length(), std::to_string(BOX));
				source += line + "\n";
			}
            continue;
        }

        temp_name = "#SDF#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
			if (scene->H_SDF) {
				line.replace(temp, temp_name.length(), std::to_string(SDF));
				source += line + "\n";
			}
            continue;
        }

        temp_name = "#QUAD#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
			if (scene->H_QUAD) {
				line.replace(temp, temp_name.length(), std::to_string(QUAD));
				source += line + "\n";
			}
            continue;
        }

        //--------------------------------- MATERIAL TYPES ---------------------------------

        temp_name = "#LIGHT#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            if (scene->ACTIVE_MATS & LIGHT)
            {
                line.replace(temp, temp_name.length(), std::to_string(LIGHT));
                source += line + "\n";
            }
            continue;
        }

        temp_name = "#DIFF#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            if (scene->ACTIVE_MATS & DIFF)
            {
                line.replace(temp, temp_name.length(), std::to_string(DIFF));
                source += line + "\n";
            }

            continue;
        }

        temp_name = "#COND#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            if (scene->ACTIVE_MATS & COND)
            {
                line.replace(temp, temp_name.length(), std::to_string(COND));
                source += line + "\n";
            }
            continue;
        }

        temp_name = "#ROUGH_COND#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            if (scene->ACTIVE_MATS & ROUGH_COND)
            {
                line.replace(temp, temp_name.length(), std::to_string(ROUGH_COND));
                source += line + "\n";
            }
            continue;
        }

        temp_name = "#DIEL#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            if (scene->ACTIVE_MATS & DIEL)
            {
                line.replace(temp, temp_name.length(), std::to_string(DIEL));
                source += line + "\n";
            }
            continue;
        }

        temp_name = "#ROUGH_DIEL#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            if (scene->ACTIVE_MATS & ROUGH_DIEL)
            {
                line.replace(temp, temp_name.length(), std::to_string(ROUGH_DIEL));
                source += line + "\n";
            }
            continue;
        }

        temp_name = "#COAT#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            if (scene->ACTIVE_MATS & COAT)
            {
                line.replace(temp, temp_name.length(), std::to_string(COAT));
                source += line + "\n";
            }
            continue;
        }

        temp_name = "#VOL#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            if (scene->ACTIVE_MATS & VOL)
            {
                line.replace(temp, temp_name.length(), std::to_string(VOL));
                source += line + "\n";
            }
            continue;
        }

        temp_name = "#TRANS#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            if (scene->ACTIVE_MATS & TRANS)
            {
                line.replace(temp, temp_name.length(), std::to_string(TRANS));
                source += line + "\n";
            }
            continue;
        }

        temp_name = "#SPECSUB#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            if (scene->ACTIVE_MATS & SPECSUB)
            {
                line.replace(temp, temp_name.length(), std::to_string(SPECSUB));
                source += line + "\n";
            }
            continue;
        }

        temp_name = "#ABS_REFR#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            line.replace(temp, temp_name.length(), std::to_string(ABS_REFR));
            source += line + "\n";
            continue;
        }

        temp_name = "#ABS_REFR2#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            line.replace(temp, temp_name.length(), std::to_string(ABS_REFR2));
            source += line + "\n";
            continue;
        }

        //--------------------------------- LIGHT ---------------------------------

        if (scene->LIGHT_COUNT)
        {

            temp_name = "#LIGHT_COUNT#";
            temp = line.find(temp_name);
            if (temp != string::npos)
            {
                line.replace(temp, temp_name.length(), std::to_string(scene->LIGHT_COUNT));
                source += line + "\n";
                continue;
            }

            temp_name = "#INV_LIGHT_COUNT#";
            temp = line.find(temp_name);
            if (temp != string::npos)
            {
                line.replace(temp, temp_name.length(), std::to_string(1.0f / scene->LIGHT_COUNT) + "f");
                source += line + "\n";
                continue;
            }

            temp_name = "#LIGHT_INDICES#";
            temp = line.find(temp_name);
            if (temp != string::npos)
            {
                string res = "";
                for (cl_uint i = 0; i < scene->LIGHT_COUNT; ++i)
                    res += std::to_string(scene->LIGHT_INDICES[i]) + ((i != (scene->LIGHT_COUNT - 1)) ? "," : "");

                line.replace(temp, temp_name.length(), res);
                source += line + "\n";
                continue;
            }
        }

        //--------------------------------- SDF TYPES ---------------------------------

        temp_name = "#SDF_SPHERE#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            line.replace(temp, temp_name.length(), std::to_string(SDF_SPHERE));
            source += line + "\n";
            continue;
        }

        temp_name = "#SDF_BOX#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            line.replace(temp, temp_name.length(), std::to_string(SDF_BOX));
            source += line + "\n";
            continue;
        }

        temp_name = "#SDF_ROUND_BOX#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            line.replace(temp, temp_name.length(), std::to_string(SDF_ROUND_BOX));
            source += line + "\n";
            continue;
        }

        temp_name = "#SDF_PLANE#";
        temp = line.find(temp_name);
        if (temp != string::npos)
        {
            line.replace(temp, temp_name.length(), std::to_string(SDF_PLANE));
            source += line + "\n";
            continue;
        }

        //-----------------------------------------------------------------------------

        source += line + "\n";
    }

    return source;
}
} // namespace kernel
} // namespace cl_help

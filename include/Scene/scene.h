#pragma once

#include <iostream>
#include <cstdlib>
#include <fstream>
#include <vector>
#include <string>
#include <CL/cl.hpp>

#include <rapidjson/document.h>
#include <rapidjson/istreamwrapper.h>

#include <Scene/geometry.h>
#include <Types/media.h>

extern std::string scene_filepath;

struct host_scene
{	
	// n_sphere, n_sdf, n_box, n_quad,
	// _____, _____, _____, total_count
	cl_uint8 object_count;
	std::vector<Mesh> cpu_meshes;

	// seperate bounce controls
	cl_int MAX_BOUNCES = 12;
	cl_int MAX_DIFF_BOUNCES = 4;
	cl_int MAX_SPEC_BOUNCES = 4;
	cl_int MAX_TRANS_BOUNCES = 12;
	cl_int MAX_SCATTERING_EVENTS = 12;

	bool H_SPHERE = false;
	bool H_SDF = false;
	bool H_BOX = false;
	bool H_QUAD = false;

	int ACTIVE_MATS = 0;

	// lights
	cl_uint LIGHT_COUNT = 0;
	std::vector<cl_uint> LIGHT_INDICES;

	// Volumetric pathtracing
	cl_bool HAS_GLOBAL_MEDIUM = false;
	cl_medium GLOBAL_MEDIUM;

	// raymarching
	cl_int MARCHING_STEPS = 128;
	cl_int SHADOW_MARCHING_STEPS = 64;

	// obj scene
	cl_bool BUILD_BVH = false;
	std::string obj_path;
	Material *obj_mat = new Material();

	void getLights()
	{
		for (cl_uint i = 0; i < object_count.s[7]; ++i)
		{
			if (cpu_meshes[i].mat.t & LIGHT)
			{
				std::cout << "-> Light Source (" << LIGHT_COUNT << ", " << i << ")" << std::endl;
				++LIGHT_COUNT;
				LIGHT_INDICES.push_back(i);
			}
		}

		std::cout << "--------------------------------" << std::endl;
	}

	template <typename T>
	void parseMaterial(T *_doc, Material &_mat)
	{
		/* color */
		if ((*_doc).HasMember("color") && (*_doc)["color"].IsArray())
		{
			for (std::size_t p = 0; p < (*_doc)["color"].GetArray().Size(); p++)
			{
				if (p == 4)
					break;
				_mat.color[p] = (*_doc)["color"][p].GetFloat();
			}
		}
		/* rougness */
		if ((*_doc).HasMember("roughness") && (*_doc)["roughness"].IsNumber())
		{
			_mat.roughness = (*_doc)["roughness"].GetFloat();
		}
		// obj's material distribution
		if ((*_doc).HasMember("dist") && (*_doc)["dist"].IsInt())
		{
			_mat.dist = 1 << (*_doc)["dist"].GetInt();
		}
		/* type */
		if ((*_doc).HasMember("type") && (*_doc)["type"].IsInt())
		{
			_mat.t = 1 << (*_doc)["type"].GetInt();

			if (_mat.t & LIGHT) {
				_mat.lobes = NullLobe;
			}
			else if (_mat.t & DIFF) {
				_mat.lobes = DiffuseReflectionLobe;
			} 
			else if (_mat.t & COND) {
				_mat.lobes = SpecularReflectionLobe;
			}
			else if (_mat.t & (ROUGH_COND | COAT)) {
				_mat.lobes = GlossyReflectionLobe;
			}
			else if (_mat.t & DIEL) {
				_mat.lobes = SpecularReflectionLobe | SpecularTransmissionLobe;
			}
			else if (_mat.t & ROUGH_DIEL) {
				_mat.lobes = GlossyReflectionLobe | GlossyTransmissionLobe;
			}

			if (_mat.t & (DIEL | ROUGH_DIEL))
			{
				_mat.eta = BK7_eta;

				/* abosrptive? */
				if ((*_doc).HasMember("absorptive") && (*_doc)["absorptive"].IsNumber())
				{
					const int cc = (*_doc)["absorptive"].GetInt();
					if (cc)
						_mat.t |= (cc == 1) ? ABS_REFR : ABS_REFR2;
				}
			}
		}
		ACTIVE_MATS |= _mat.t;
	}

	void load()
	{
		using namespace rapidjson;

		std::cout << "--------------------------------" << std::endl;
		std::cout << "Loading (" << scene_filepath << ")\n";
		std::ifstream ifs(scene_filepath);
		IStreamWrapper isw(ifs);

		Document document;
		document.ParseStream(isw);

		assert(document.IsObject());
		assert(document.HasMember("scene"));

		//---------------------- GLOBAL MEDIUM -------------------------
		HAS_GLOBAL_MEDIUM = document.HasMember("global_medium");
		if (HAS_GLOBAL_MEDIUM)
		{
			GLOBAL_MEDIUM.density = document["global_medium"].HasMember("density") ? document["global_medium"]["density"].GetFloat() : 0.1f;
			GLOBAL_MEDIUM.sigmaA = GLOBAL_MEDIUM.density * (document["global_medium"].HasMember("sigmaA") ? document["global_medium"]["sigmaA"].GetFloat() : 0.2f);
			GLOBAL_MEDIUM.sigmaS = GLOBAL_MEDIUM.density * (document["global_medium"].HasMember("sigmaS") ? document["global_medium"]["sigmaS"].GetFloat() : 1.0f);
			GLOBAL_MEDIUM.sigmaT = GLOBAL_MEDIUM.sigmaA + GLOBAL_MEDIUM.sigmaS;
			GLOBAL_MEDIUM.absorptionOnly = (GLOBAL_MEDIUM.sigmaS == 0.0f);
		}

		//---------------------------------- Render Settings ----------------------------------
		if (document.HasMember("settings"))
		{
			MAX_BOUNCES = document["settings"].HasMember("MAX_BOUNCES") ? document["settings"]["MAX_BOUNCES"].GetInt() : 12;
			MAX_DIFF_BOUNCES = document["settings"].HasMember("MAX_DIFF_BOUNCES") ? document["settings"]["MAX_DIFF_BOUNCES"].GetInt() : 4;
			MAX_SPEC_BOUNCES = document["settings"].HasMember("MAX_SPEC_BOUNCES") ? document["settings"]["MAX_SPEC_BOUNCES"].GetInt() : 4;
			MAX_TRANS_BOUNCES = document["settings"].HasMember("MAX_TRANS_BOUNCES") ? document["settings"]["MAX_TRANS_BOUNCES"].GetInt() : 12;
			MAX_SCATTERING_EVENTS = document["settings"].HasMember("MAX_SCATTERING_EVENTS") ? document["settings"]["MAX_SCATTERING_EVENTS"].GetInt() : 12;

			MARCHING_STEPS = document["settings"].HasMember("MARCHING_STEPS") ? document["settings"]["MARCHING_STEPS"].GetInt() : 128;
			SHADOW_MARCHING_STEPS = document["settings"].HasMember("SHADOW_MARCHING_STEPS") ? document["settings"]["SHADOW_MARCHING_STEPS"].GetInt() : 64;
		}

		//---------------------------------- Scene ----------------------------------
		if (document.HasMember("scene"))
		{

			//---------------------------------- OBJ ----------------------------------
			BUILD_BVH = document["scene"].HasMember("obj") && document["scene"]["obj"].IsObject() &&
						document["scene"]["obj"].HasMember("path") && document["scene"]["obj"]["path"].IsString();
			if (BUILD_BVH)
			{
				// .obj name
				obj_path = document["scene"]["obj"]["path"].GetString();

				// obj's material
				if (document["scene"]["obj"].HasMember("material") &&
					document["scene"]["obj"]["material"].IsObject())
				{

					// obj's material color
					if (document["scene"]["obj"]["material"].HasMember("color") &&
						document["scene"]["obj"]["material"]["color"].IsArray())
					{

						for (int p = 0; p < 3; p++)
						{
							obj_mat->color[p] = document["scene"]["obj"]["material"]["color"][p].GetFloat();
						}
					}

					// obj's material roughness
					if (document["scene"]["obj"]["material"].HasMember("roughness") &&
						document["scene"]["obj"]["material"]["roughness"].IsNumber())
					{

						obj_mat->roughness = document["scene"]["obj"]["material"]["roughness"].GetFloat();
					}

					// obj's material distribution
					if (document["scene"]["obj"]["material"].HasMember("dist") &&
						document["scene"]["obj"]["material"]["dist"].IsInt())
					{
						obj_mat->dist = 1 << document["scene"]["obj"]["material"]["dist"].GetInt();
					}

					// obj's material type
					if (document["scene"]["obj"]["material"].HasMember("type") &&
						document["scene"]["obj"]["material"]["type"].IsInt())
					{

						obj_mat->t = 1 << document["scene"]["obj"]["material"]["type"].GetInt();

						if (obj_mat->t & LIGHT) {
							obj_mat->lobes = NullLobe;
						}
						else if (obj_mat->t & DIFF) {
							obj_mat->lobes = DiffuseReflectionLobe;
						}
						else if (obj_mat->t & COND) {
							obj_mat->lobes = SpecularReflectionLobe;
						}
						else if (obj_mat->t & (ROUGH_COND | COAT)) {
							obj_mat->lobes = GlossyReflectionLobe;
						}
						else if (obj_mat->t & DIEL) {
							obj_mat->lobes = SpecularReflectionLobe | SpecularTransmissionLobe;
						}
						else if (obj_mat->t & ROUGH_DIEL) {
							obj_mat->lobes = GlossyReflectionLobe | GlossyTransmissionLobe;
						}

						if (obj_mat->t & (DIEL | ROUGH_DIEL))
						{
							obj_mat->eta = BK7_eta;

							if (document["scene"]["obj"]["material"].HasMember("absorptive") &&
								document["scene"]["obj"]["material"]["absorptive"].IsNumber())
							{

								int cc = document["scene"]["obj"]["material"]["absorptive"].GetInt();
								if (cc)
								{
									obj_mat->t |= (cc == 1) ? ABS_REFR : ABS_REFR2;
								}
							}
						}
					}
					ACTIVE_MATS |= obj_mat->t;
				}
			}

			//---------------------------------- Spheres ----------------------------------
			if (document["scene"].HasMember("spheres") && document["scene"]["spheres"].IsArray())
			{
				GenericArray<false, Value::ValueType> spheres = document["scene"]["spheres"].GetArray();

				H_SPHERE = spheres.Size() > 0;
				object_count.s[0] = spheres.Size();

				object_count.s[7] += object_count.s[0];
				cpu_meshes.resize(object_count.s[7]);

				for (cl_uint i = 0; i < object_count.s[0]; ++i)
				{

					// assign mesh type
					cpu_meshes[i].t = SPHERE;

					// sphere's position
					if (spheres[i].HasMember("pos") &&
						spheres[i]["pos"].IsArray())
					{

						for (int p = 0; p < 3; p++)
						{
							cpu_meshes[i].position[p] = spheres[i]["pos"][p].GetFloat();
						}
					}

					// sphere's radius
					if (spheres[i].HasMember("radius") &&
						spheres[i]["radius"].IsNumber())
					{

						cpu_meshes[i].joker.s[0] = spheres[i]["radius"].GetFloat();
					}

					// sphere's material
					if (spheres[i].HasMember("material") && spheres[i]["material"].IsObject())
					{
						parseMaterial(&spheres[i]["material"], cpu_meshes[i].mat);
					}
				}
			}

			//---------------------------------- SDF ----------------------------------
			if (document["scene"].HasMember("sdfs") && document["scene"]["sdfs"].IsArray())
			{
				GenericArray<false, Value::ValueType> sdfs = document["scene"]["sdfs"].GetArray();

				H_SDF = sdfs.Size() > 0;
				object_count.s[1] = sdfs.Size();

				object_count.s[7] += object_count.s[1];
				cpu_meshes.resize(object_count.s[7]);

				int arr_pos = object_count.s[0];
				for (cl_uint i = 0; i < object_count.s[1]; ++i)
				{

					// assign mesh type
					cpu_meshes[arr_pos].t = SDF;

					// sdf's position
					if (sdfs[i].HasMember("pos") &&
						sdfs[i]["pos"].IsArray())
					{

						for (int p = 0; p < 3; p++)
						{
							cpu_meshes[arr_pos].position[p] = sdfs[i]["pos"][p].GetFloat();
						}
					}

					// sdf type
					if (sdfs[i].HasMember("type") &&
						sdfs[i]["type"].IsInt())
					{

						cpu_meshes[arr_pos].t |= (1 << sdfs[i]["type"].GetInt());
					}

					// joker values
					if (sdfs[i].HasMember("params") &&
						sdfs[i]["params"].IsArray())
					{

						GenericArray<false, Value::ValueType> params = sdfs[i]["params"].GetArray();

						for (cl_uint i = 0; i < params.Size(); ++i)
						{
							cpu_meshes[arr_pos].joker.s[i] = params[i].GetFloat();
						}
					}

					// sdf's material
					if (sdfs[i].HasMember("material") && sdfs[i]["material"].IsObject())
					{
						parseMaterial(&sdfs[i]["material"], cpu_meshes[arr_pos].mat);
					}

					arr_pos++;
				}
			}

			//---------------------------------- BOX ----------------------------------
			if (document["scene"].HasMember("boxes") && document["scene"]["boxes"].IsArray())
			{
				GenericArray<false, Value::ValueType> boxes = document["scene"]["boxes"].GetArray();

				H_BOX = boxes.Size() > 0;
				object_count.s[2] = boxes.Size();

				object_count.s[7] += object_count.s[2];
				cpu_meshes.resize(object_count.s[7]);

				int arr_pos = object_count.s[0] + object_count.s[1];
				for (cl_uint i = 0; i < object_count.s[2]; ++i)
				{

					// assign mesh type
					cpu_meshes[arr_pos].t = BOX;

					// box's min corner
					if (boxes[i].HasMember("pos") &&
						boxes[i]["pos"].IsArray())
					{

						for (int p = 0; p < 3; p++)
						{
							cpu_meshes[arr_pos].position[p] = boxes[i]["pos"][p].GetFloat();
						}
					}

					// box's max corner
					if (boxes[i].HasMember("scale") &&
						boxes[i]["scale"].IsArray())
					{

						for (int p = 0; p < 3; p++)
						{
							cpu_meshes[arr_pos].joker.s[p] = boxes[i]["scale"][p].GetFloat();
						}
					}

					// box's material
					if (boxes[i].HasMember("material") && boxes[i]["material"].IsObject())
					{
						parseMaterial(&boxes[i]["material"], cpu_meshes[arr_pos].mat);
					}

					arr_pos++;
				}
			}

			//---------------------------------- QUAD ----------------------------------
			if (document["scene"].HasMember("quads") && document["scene"]["quads"].IsArray())
			{
				GenericArray<false, Value::ValueType> quads = document["scene"]["quads"].GetArray();

				H_QUAD = quads.Size() > 0;
				object_count.s[3] = quads.Size();

				object_count.s[7] += object_count.s[3];
				cpu_meshes.resize(object_count.s[7]);

				int arr_pos = object_count.s[0] + object_count.s[1] + object_count.s[2];
				for (cl_uint i = 0; i < object_count.s[3]; ++i)
				{

					// assign mesh type
					cpu_meshes[arr_pos].t = QUAD;

					// quad's vertices
					if (quads[i].HasMember("vertices") &&
						quads[i]["vertices"].IsArray())
					{

						GenericArray<false, Value::ValueType> vertices = quads[i]["vertices"].GetArray();

						for (int p = 0; p < vertices.Size(); p++)
						{
							cpu_meshes[arr_pos].joker.s[p] = vertices[p].GetFloat();
						}

						// calculate quad's normal
						vec4 normal = cross(
							vec3(cpu_meshes[arr_pos].joker.s[3], cpu_meshes[arr_pos].joker.s[4], cpu_meshes[arr_pos].joker.s[5]),
							vec3(cpu_meshes[arr_pos].joker.s[6], cpu_meshes[arr_pos].joker.s[7], cpu_meshes[arr_pos].joker.s[8])
						);

						cpu_meshes[arr_pos].joker.s[12] = normal.lengthsq3();

						normal.normalize();
						cpu_meshes[arr_pos].joker.s[9] = normal.x;
						cpu_meshes[arr_pos].joker.s[10] = normal.y;
						cpu_meshes[arr_pos].joker.s[11] = normal.z;

					}

					// quad's material
					if (quads[i].HasMember("material") && quads[i]["material"].IsObject())
					{
						parseMaterial(&quads[i]["material"], cpu_meshes[arr_pos].mat);
					}

					arr_pos++;
				}
			}
		}

		if (ACTIVE_MATS & LIGHT)
			this->getLights();
	}
};

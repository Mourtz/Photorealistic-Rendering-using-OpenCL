#pragma once

#include <iostream>

#define STB_IMAGE_IMPLEMENTATION
#include <stb_image.h>

#include <align.h>
#include <map>
#include <Math/linear_algebra.h>

struct Texture
{
	int width, height, nrComponents;
	float* data;
};

Texture* loadHDR(const char* filepath) {
	Texture* res = new Texture();

	//stbi_set_flip_vertically_on_load(true);

	res->data = stbi_loadf(filepath, &res->width, &res->height, &res->nrComponents, 0);
	cout << "Successfully loaded the given HDR image(" << res->width << "x" << res->height << "x" << res->nrComponents << ")" << std::endl;

	return res;
}

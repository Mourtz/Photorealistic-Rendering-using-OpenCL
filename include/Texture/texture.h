#pragma once

#include <iostream>

#define STB_IMAGE_IMPLEMENTATION
#include <stb_image.h>
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include <stb_image_write.h>

#include <align.h>
#include <map>
#include <Math/linear_algebra.h>

template <typename T>
struct Texture
{
	int width, height, nrComponents;
	T* data;
};

inline Texture<unsigned char>* loadPNG(const char* filepath) {
	Texture<unsigned char>* res = new Texture<unsigned char>();

	//stbi_set_flip_vertically_on_load(true);
	res->data = stbi_load(filepath, &res->width, &res->height, &res->nrComponents, 0);
	std::cout << "Successfully loaded the given PNG image(" << res->width << "x" << res->height << "x" << res->nrComponents << ")" << std::endl;

	return res;
}

inline Texture<float>* loadHDR(const char* filepath) {
	Texture<float>* res = new Texture<float>();

	//stbi_set_flip_vertically_on_load(true);
	res->data = stbi_loadf(filepath, &res->width, &res->height, &res->nrComponents, 0);
	std::cout << "Successfully loaded the given HDR image(" << res->width << "x" << res->height << "x" << res->nrComponents << ")" << std::endl;

	return res;
}

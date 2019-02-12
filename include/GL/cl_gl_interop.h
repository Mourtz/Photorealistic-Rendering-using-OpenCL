#pragma once

#include <iostream>
#include <vector>
#include <math.h>
#include <vector>

#include <utils.h>
#include <Texture/texture.h>
#include <GL/user_interaction.h>

// OpenGL window
GLFWwindow* window;

// window width
int window_width = 1280;
// window height
int window_height = 720;
// enviroment map filepath
std::string env_map_filepath = "";
// encoder
unsigned char encoder(0);

// quad vertices
const GLfloat quad_vertices[] = { -1.0, -1.0, 1.0, -1.0, -1.0, 1.0, -1.0, 1.0, 1.0, -1.0, 1.0, 1.0 };

// display texture
GLuint tex0, tex1/*, tex2*/;

// OpenGL vertex buffer object
GLuint vbo;

const std::string vert_filepath = "../shaders/vert.glsl";
const std::string tonemapper_filepath = "../shaders/tonemapper.glsl";

bool initGL(){

	if(glfwInit()) std::cout << "GLFW initialized!" << std::endl;
	else return false;

	glfwWindowHint(GLFW_VISIBLE, GL_FALSE);
	glfwWindowHint(GLFW_RESIZABLE, GL_FALSE);

	window = glfwCreateWindow(window_width, window_height, "OpenCL-Pathtracer", NULL, NULL);
	glfwMakeContextCurrent(window);

	glfwSetKeyCallback(window, key_callback);
	glfwSetMouseButtonCallback(window, mouse_button_callback);
	glfwSetCursorPosCallback(window, cursor_pos_callback);
	glfwSetScrollCallback(window, scroll_callback);
	//glfwSetWindowSizeCallback(window, window_size_callback);

	// initialise OpenGL extensions
	if(glewInit() == GLEW_OK) std::cout << "GLEW initialized \n";
	else return false;

	// initialise OpenGL
	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glMatrixMode(GL_PROJECTION);
	gluOrtho2D(0.0, window_width, 0.0, window_height);

	// create vbo
	glGenBuffers(1, &vbo);
	glBindBuffer(GL_ARRAY_BUFFER, vbo);
	glBufferData(GL_ARRAY_BUFFER, sizeof(quad_vertices), quad_vertices, GL_STATIC_DRAW);

	// radiance
	glGenTextures(1, &tex0);
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, tex0);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, window_width, window_height, 0, GL_RGBA, GL_FLOAT, NULL);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

	// enviroment map
	glGenTextures(1, &tex1);
	glActiveTexture(GL_TEXTURE1);
	glBindTexture(GL_TEXTURE_2D, tex1);
	if (!env_map_filepath.empty()) {
		Texture<float>* cubemap = loadHDR(env_map_filepath.c_str());
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB32F, cubemap->width, cubemap->height, 0, GL_RGB, GL_FLOAT, &cubemap->data[0]);
		stbi_image_free(cubemap->data);
		delete cubemap;
	} else {
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB32F, 1, 1, 0, GL_RGB, GL_FLOAT, NULL);
	}
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

	// noise texture
	// glGenTextures(1, &tex2);
	// glActiveTexture(GL_TEXTURE2);
	// glBindTexture(GL_TEXTURE_2D, tex2);

	// Texture<unsigned char>* noise_tex = loadPNG("../resources/textures/rgb_noise1024.png");
	// glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, noise_tex->width, noise_tex->height, 0, GL_RGB, GL_UNSIGNED_BYTE, &noise_tex->data[0]);
	// stbi_image_free(noise_tex->data);
	// delete noise_tex;

	// glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	// glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	// glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	// glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

	// glActiveTexture(GL_TEXTURE0);
	// glBindTexture(GL_TEXTURE_2D, tex0);

	// Create and compile the vertex shader
	std::string vertStr = utils::ReadFile(vert_filepath);
	const char* vertSrc = vertStr.c_str();

	GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
	glShaderSource(vertexShader, 1, &vertSrc, NULL);
	glCompileShader(vertexShader);

	// Create and compile the fragment shader
	std::string fragmentStr = utils::ReadFile(tonemapper_filepath);
	const char* fragmentSrc = fragmentStr.c_str();

	GLuint fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
	glShaderSource(fragmentShader, 1, &fragmentSrc, NULL);
	glCompileShader(fragmentShader);

	// Link the vertex and fragment shader into a shader program
	GLuint shaderProgram = glCreateProgram();
	glAttachShader(shaderProgram, vertexShader);
	glAttachShader(shaderProgram, fragmentShader);
	glLinkProgram(shaderProgram);
	glUseProgram(shaderProgram);

	glUniform1i(glGetUniformLocation(shaderProgram, "u_tex"), 0);
	glUniform2f(glGetUniformLocation(shaderProgram, "u_resolution"), window_width, window_height);

	// load vbo
	GLint posAttrib = glGetAttribLocation(shaderProgram, "position");
	glEnableVertexAttribArray(posAttrib);
	glVertexAttribPointer(posAttrib, 2, GL_FLOAT, GL_FALSE, 0, 0);

	std::cout << "OpenGL initialized \n";

	stbi_flip_vertically_on_write(true);

	return true;
}

void saveImage() {
	double tStart = glfwGetTime();
	
	if (encoder == 0) {
		GLubyte* pixels = new GLubyte[4 * window_width * window_height];
		glReadPixels(0, 0, window_width, window_height, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
		stbi_write_png("render.png", window_width, window_height, 4, pixels, 0);
		delete pixels;
	} else if (encoder == 1) {
		float* pixels = new float[3 * window_width * window_height];
		glGetTexImage(GL_TEXTURE_2D, 0, GL_RGB, GL_FLOAT, pixels);
		stbi_write_hdr("render.hdr", window_width, window_height, 3, pixels);
		delete pixels;
	}

	std::cout << std::endl << "succesfully saved in ( " << glfwGetTime() - tStart << "s )" << std::endl;
}

void createVBO(GLuint* vbo){

	//create vertex buffer object
	glGenBuffers(1, vbo);
	glBindBuffer(GL_ARRAY_BUFFER, *vbo);

	//initialise VBO
	unsigned int size = window_width * window_height * sizeof(cl_float4);
	glBufferData(GL_ARRAY_BUFFER, size, 0, GL_DYNAMIC_DRAW);
	glBindBuffer(GL_ARRAY_BUFFER, 0);
}

void drawGL(){
	glClear(GL_COLOR_BUFFER_BIT);
	glDrawArrays(GL_TRIANGLES, 0, 6);
}

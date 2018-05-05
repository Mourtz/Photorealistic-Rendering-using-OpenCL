#pragma once

#include <iostream>
#include <vector>
#include <math.h>
#include <vector>

#include <Texture/lodepng.h>
#include <GL/user_interaction.h>

// OpenGL window
GLFWwindow* window;

// window width
int window_width = 1280;
// window height
int window_height = 720;

// quad vertices
const GLfloat quad_vertices[] = { -1.0, -1.0, 1.0, -1.0, -1.0, 1.0, -1.0, 1.0, 1.0, -1.0, 1.0, 1.0 };

// display texture
GLuint tex0;

// OpenGL vertex buffer object
GLuint vbo;

const string vert_filepath = "../shaders/vert.glsl";
const string tonemapper_filepath = "../shaders/tonemapper.glsl";

string readFile(string filepath) {
	string str;

	std::ifstream file(filepath);
	if (!file) {
		cout << "\nCouldn't find OpenCL file (" + filepath + ')' << endl << "Exiting..." << endl;
		cin.get();
		exit(1);
	}

	string line;
	while (std::getline(file, line)) {
		str += line + '\n';
	}

	return str;
}

bool initGL(){

	if(glfwInit()) cout << "GLFW initialized!" << std::endl;
	else return false;

	glfwWindowHint(GLFW_VISIBLE, GL_FALSE);
	glfwWindowHint(GLFW_RESIZABLE, GL_FALSE);

	window = glfwCreateWindow(window_width, window_height, "OpenCL-Pathtracer", NULL, NULL);
	glfwMakeContextCurrent(window);

	glfwSetKeyCallback(window, key_callback);
	glfwSetMouseButtonCallback(window, mouse_button_callback);
	glfwSetCursorPosCallback(window, cursor_pos_callback);
	//glfwSetWindowSizeCallback(window, window_size_callback);

	// initialise OpenGL extensions
	if(glewInit() == GLEW_OK) cout << "GLEW initialized \n";
	else return false;

	// initialise OpenGL
	glClearColor(0.0, 0.0, 0.0, 1.0);
	glMatrixMode(GL_PROJECTION);
	gluOrtho2D(0.0, window_width, 0.0, window_height);

	// create vbo
	glGenBuffers(1, &vbo);
	glBindBuffer(GL_ARRAY_BUFFER, vbo);
	glBufferData(GL_ARRAY_BUFFER, sizeof(quad_vertices), quad_vertices, GL_STATIC_DRAW);

	// generate tex0
	glGenTextures(1, &tex0);
	glBindTexture(GL_TEXTURE_2D, tex0);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	//32 bit color depth
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, window_width, window_height, 0, GL_RGBA, GL_FLOAT, NULL);


	// Create and compile the vertex shader
	string vertStr = readFile(vert_filepath);
	const char* vertSrc = vertStr.c_str();

	GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
	glShaderSource(vertexShader, 1, &vertSrc, NULL);
	glCompileShader(vertexShader);

	// Create and compile the fragment shader
	string fragmentStr = readFile(tonemapper_filepath);
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


	cout << "OpenGL initialized \n";

	return true;
}

void saveImage() {
	unsigned int tex_size = 3 * window_width * window_height;

	GLubyte* pixels = new GLubyte[tex_size];
	glReadPixels(0, 0, window_width, window_height, GL_RGB, GL_UNSIGNED_BYTE, pixels);

	vector<unsigned char> image;
	image.reserve(tex_size);
	for (unsigned int i = tex_size; i > 0;) {
		image.push_back((unsigned char)(pixels[--i]));
		image.push_back((unsigned char)(pixels[--i]));
		image.push_back((unsigned char)(pixels[--i]));
		image.push_back((unsigned char)(255.0f));
	}

	unsigned error = lodepng::encode("render.png", image, window_width, window_height);
	if (error)
		cout << "encoder error " << error << ": " << lodepng_error_text(error) << endl;
	else
		cout << "\nsuccesfully rendered to texture" << endl;
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

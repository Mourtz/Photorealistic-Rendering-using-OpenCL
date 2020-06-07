#pragma once

#ifndef FLT_MAX
#define FLT_MAX 3.402823466e+38F
#endif

#include <CL/cl.hpp>
#include <Math/linear_algebra.h>
#include <vector>

struct Tri {
	cl_uint4 face;
	cl_uint4 normals;
	vec3 bbMin;
	vec3 bbMax;
};

class MathHelp {
public:
	static cl_float degToRad(cl_float deg);
	static void getAABB(
		std::vector<cl_float4> vertices, vec3& bbMin, vec3& bbMax
	);
	static void getAABB(
		std::vector<vec3> vertices, vec3& bbMin, vec3& bbMax
	);
	static void getAABB(
		std::vector<vec3> bbMins, std::vector<vec3> bbMaxs,
		vec3* bbMin, vec3* bbMax
	);
	static cl_float getOverlapSA(vec3 bbA, vec3 bbB);
	static cl_float getSurfaceArea(vec3 bbMin, vec3 bbMax);
	static void getTriangleAABB(
		cl_float4 v0, cl_float4 v1, cl_float4 v2, vec3* bbMin, vec3* bbMax
	);
	static vec3 getTriangleCenter(
		cl_float4 v0, cl_float4 v1, cl_float4 v2
	);
	static vec3 getTriangleCentroid(
		cl_float4 v0, cl_float4 v1, cl_float4 v2
	);
	static vec3 intersectLinePlane(
		vec3 p, vec3 q, vec3 x, vec3 nl, bool* isParallel
	);
	static short longestAxis(vec3 bbMin, vec3 bbMax);
	static vec3 phongTessellate(
		const vec3 p1, const vec3 p2, const vec3 p3,
		const vec3 n1, const vec3 n2, const vec3 n3,
		const float alpha, const float u, const float v
	);
	static vec3 projectOnPlane(vec3 q, vec3 p, vec3 n);
	static cl_float radToDeg(cl_float rad);
	static void triCalcAABB(Tri* tri, const std::vector<cl_float4>* vertices, const std::vector<cl_float4>* normals);
	static void triThicknessAndSidedrop(
		const vec3 p1, const vec3 p2, const vec3 p3,
		const vec3 n1, const vec3 n2, const vec3 n3,
		float* thickness, vec3* sidedropMin, vec3* sidedropMax
	);
};

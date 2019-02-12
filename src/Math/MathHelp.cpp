#include <Math/MathHelp.h>

using std::vector;

const cl_float RENDER_PHONGTESS = 0;

cl_float MathHelp::degToRad(cl_float deg) {
	return (deg * M_PI / 180.0f);
}

void MathHelp::getAABB(vector<cl_float4> vertices, vec3* bbMin, vec3* bbMax) {
	*bbMin = vec3(vertices[0].x, vertices[0].y, vertices[0].z);
	*bbMax = vec3(vertices[0].x, vertices[0].y, vertices[0].z);

	for (cl_uint i = 1; i < vertices.size(); i++) {
		cl_float4 v = vertices[i];

		(*bbMin)[0] = ((*bbMin)[0] < v.x) ? (*bbMin)[0] : v.x;
		(*bbMin)[1] = ((*bbMin)[1] < v.y) ? (*bbMin)[1] : v.y;
		(*bbMin)[2] = ((*bbMin)[2] < v.z) ? (*bbMin)[2] : v.z;

		(*bbMax)[0] = ((*bbMax)[0] > v.x) ? (*bbMax)[0] : v.x;
		(*bbMax)[1] = ((*bbMax)[1] > v.y) ? (*bbMax)[1] : v.y;
		(*bbMax)[2] = ((*bbMax)[2] > v.z) ? (*bbMax)[2] : v.z;
	}
}

void MathHelp::getAABB(
	vector<vec3> bbMins, vector<vec3> bbMaxs, vec3* bbMin, vec3* bbMax
) {
	(*bbMin)[0] = bbMins[0][0];
	(*bbMin)[1] = bbMins[0][1];
	(*bbMin)[2] = bbMins[0][2];

	(*bbMax)[0] = bbMaxs[0][0];
	(*bbMax)[1] = bbMaxs[0][1];
	(*bbMax)[2] = bbMaxs[0][2];

	for (cl_uint i = 1; i < bbMins.size(); i++) {
		(*bbMin)[0] = fmin(bbMins[i][0], (*bbMin)[0]);
		(*bbMin)[1] = fmin(bbMins[i][1], (*bbMin)[1]);
		(*bbMin)[2] = fmin(bbMins[i][2], (*bbMin)[2]);

		(*bbMax)[0] = fmax(bbMaxs[i][0], (*bbMax)[0]);
		(*bbMax)[1] = fmax(bbMaxs[i][1], (*bbMax)[1]);
		(*bbMax)[2] = fmax(bbMaxs[i][2], (*bbMax)[2]);
	}
}

cl_float MathHelp::getOverlapSA(vec3 bbA, vec3 bbB) {
	cl_float overlapSA = 0.0f;

	cl_float sideX = bbA.x - bbB.x;
	cl_float sideY = bbA.y - bbB.y;
	cl_float sideZ = bbA.z - bbB.z;

	if (fmin(sideX, fmin(sideY, sideZ)) > 0.0f) {
		overlapSA = 2.0f * (sideX * sideY + sideX * sideZ + sideY * sideZ);
	}

	return overlapSA;
};

cl_float MathHelp::getSurfaceArea(vec3 bbMin, vec3 bbMax) {
	cl_float xy = fabs(bbMax[0] - bbMin[0]) * fabs(bbMax[1] - bbMin[1]);
	cl_float zy = fabs(bbMax[2] - bbMin[2]) * fabs(bbMax[1] - bbMin[1]);
	cl_float xz = fabs(bbMax[0] - bbMin[0]) * fabs(bbMax[2] - bbMin[2]);

	return 2.0f * (xy + zy + xz);
}

void MathHelp::getTriangleAABB(cl_float4 v0, cl_float4 v1, cl_float4 v2, vec3* bbMin, vec3* bbMax) {
	vector<cl_float4> vertices;

	vertices.push_back(v0);
	vertices.push_back(v1);
	vertices.push_back(v2);

	MathHelp::getAABB(vertices, bbMin, bbMax);
}

vec3 MathHelp::getTriangleCenter(cl_float4 v0, cl_float4 v1, cl_float4 v2) {
	vec3 bbMin;
	vec3 bbMax;
	MathHelp::getTriangleAABB(v0, v1, v2, &bbMin, &bbMax);

	return (bbMax - bbMin) / 2.0f;
}

vec3 MathHelp::getTriangleCentroid(cl_float4 v0, cl_float4 v1, cl_float4 v2) {
	vec3 a(v0.x, v0.y, v0.z);
	vec3 b(v1.x, v1.y, v1.z);
	vec3 c(v2.x, v2.y, v2.z);

	return (a + b + c) / 3.0f;
}

vec3 MathHelp::intersectLinePlane(vec3 p, vec3 q, vec3 x, vec3 nl, bool* isParallel) {
	vec3 hit;
	vec3 u = q - p;
	vec3 w = p - x;
	cl_float d = dot(nl, u);

	if (fabs(d) < 0.000001f) {
		*isParallel = true;
	}
	else {
		cl_float t = -dot(nl, w) / d;
		hit = p + u * t;
		*isParallel = false;
	}

	return hit;
}

short MathHelp::longestAxis(vec3 bbMin, vec3 bbMax) {
	vec3 sides = bbMax - bbMin;

	if (sides[0] > sides[1]) {
		return (sides[0] > sides[2]) ? 0 : 2;
	}
	else { // sides[1] > sides[0]
		return (sides[1] > sides[2]) ? 1 : 2;
	}
}

vec3 MathHelp::projectOnPlane(vec3 q, vec3 p, vec3 n) {
	return q - dot(q - p, n) * n;
}

vec3 MathHelp::phongTessellate(
	const vec3 p1, const vec3 p2, const vec3 p3,
	const vec3 n1, const vec3 n2, const vec3 n3,
	const float alpha, const float u, const float v
) {
	float w = 1.0f - u - v;
	vec3 pBary = p1 * u + p2 * v + p3 * w;
	vec3 pTessellated =
		u * MathHelp::projectOnPlane(pBary, p1, n1) +
		v * MathHelp::projectOnPlane(pBary, p2, n2) +
		w * MathHelp::projectOnPlane(pBary, p3, n3);

	return (1.0f - alpha) * pBary + alpha * pTessellated;
}

cl_float MathHelp::radToDeg(cl_float rad) {
	return (rad * 180.0f / M_PI);
}

void MathHelp::triThicknessAndSidedrop(
	const vec3 p1, const vec3 p2, const vec3 p3,
	const vec3 n1, const vec3 n2, const vec3 n3,
	float* thickness, vec3* sidedropMin, vec3* sidedropMax
) {
	float alpha = RENDER_PHONGTESS;

	vec3 e12 = p2 - p1;
	vec3 e13 = p3 - p1;
	vec3 e23 = p3 - p2;
	vec3 e31 = p1 - p3;
	vec3 c12 = alpha * (dot(n2, e12) * n2 - dot(n1, e12) * n1);
	vec3 c23 = alpha * (dot(n3, e23) * n3 - dot(n2, e23) * n2);
	vec3 c31 = alpha * (dot(n1, e31) * n1 - dot(n3, e31) * n3);
	vec3 ng = normalize(cross(e12, e13));

	float k_tmp = dot(ng, c12 - c23 - c31);
	float k = 1.0f / (4.0f * dot(ng, c23) * dot(ng, c31) - k_tmp * k_tmp);

	float u = k * (
		2.0f * dot(ng, c23) * dot(ng, c31 + e31) +
		dot(ng, c23 - e23) * dot(ng, c12 - c23 - c31)
		);
	float v = k * (
		2.0f * dot(ng, c31) * dot(ng, c23 - e23) +
		dot(ng, c31 + e31) * dot(ng, c12 - c23 - c31)
		);

	u = (u < 0.0f || u > 1.0f) ? 0.0f : u;
	v = (v < 0.0f || v > 1.0f) ? 0.0f : v;

	vec3 pt = MathHelp::phongTessellate(p1, p2, p3, n1, n2, n3, alpha, u, v);
	*thickness = dot(ng, pt - p1);

	vec3 ptsd[9] = {
		MathHelp::phongTessellate(p1, p2, p3, n1, n2, n3, alpha, 0.0f, 0.5f),
		MathHelp::phongTessellate(p1, p2, p3, n1, n2, n3, alpha, 0.5f, 0.0f),
		MathHelp::phongTessellate(p1, p2, p3, n1, n2, n3, alpha, 0.5f, 0.5f),
		MathHelp::phongTessellate(p1, p2, p3, n1, n2, n3, alpha, 0.25f, 0.75f),
		MathHelp::phongTessellate(p1, p2, p3, n1, n2, n3, alpha, 0.75f, 0.25f),
		MathHelp::phongTessellate(p1, p2, p3, n1, n2, n3, alpha, 0.25f, 0.0f),
		MathHelp::phongTessellate(p1, p2, p3, n1, n2, n3, alpha, 0.75f, 0.0f),
		MathHelp::phongTessellate(p1, p2, p3, n1, n2, n3, alpha, 0.0f, 0.25f),
		MathHelp::phongTessellate(p1, p2, p3, n1, n2, n3, alpha, 0.0f, 0.75f)
	};

	*sidedropMin = ptsd[0];
	*sidedropMax = ptsd[0];

	for (cl_uint i = 1; i < 9; i++) {
		*sidedropMin = min3(*sidedropMin, ptsd[i]);
		*sidedropMax = max3(*sidedropMax, ptsd[i]);
	}
}

void MathHelp::triCalcAABB(
	Tri* tri, const vector<cl_float4>* vertices, const vector<cl_float4>* normals
) {
	vector<cl_float4> v;
	v.push_back((*vertices)[tri->face.x]);
	v.push_back((*vertices)[tri->face.y]);
	v.push_back((*vertices)[tri->face.z]);

	vec3 bbMin, bbMax;
	MathHelp::getAABB(v, &bbMin, &bbMax);
	tri->bbMin = bbMin;
	tri->bbMax = bbMax;

	// ALPHA <= 0.0, no Phong Tessellation
	if (RENDER_PHONGTESS <= 0.0f) {
		return;
	}

	vec3 p1 = vec3(v[0].x, v[0].y, v[0].z);
	vec3 p2 = vec3(v[1].x, v[1].y, v[1].z);
	vec3 p3 = vec3(v[2].x, v[2].y, v[2].z);

	cl_float4 fn1 = (*normals)[tri->normals.x];
	cl_float4 fn2 = (*normals)[tri->normals.y];
	cl_float4 fn3 = (*normals)[tri->normals.z];

	vec3 n1 = vec3(fn1.x, fn1.y, fn1.z);
	vec3 n2 = vec3(fn2.x, fn2.y, fn2.z);
	vec3 n3 = vec3(fn3.x, fn3.y, fn3.z);

	// Normals are the same, which means no Phong Tessellation possible
	vec3 test = (n1 - n2) + (n2 - n3);
	if (
		fabs(test.x) <= 0.000001f &&
		fabs(test.y) <= 0.000001f &&
		fabs(test.z) <= 0.000001f
		) {
		return;
	}


	float thickness;
	vec3 sidedropMin, sidedropMax;
	MathHelp::triThicknessAndSidedrop(p1, p2, p3, n1, n2, n3, &thickness, &sidedropMin, &sidedropMax);

	// Grow bigger according to thickness and sidedrop
	vec3 e12 = p2 - p1;
	vec3 e13 = p3 - p1;
	vec3 e23 = p3 - p2;
	vec3 e31 = p1 - p3;
	vec3 ng = normalize(cross(e12, e13));

	vec3 p1thick = p1 + thickness * ng;
	vec3 p2thick = p2 + thickness * ng;
	vec3 p3thick = p3 + thickness * ng;

	tri->bbMin = min3(min3(tri->bbMin, p1thick), min3(p2thick, p3thick));
	tri->bbMax = max3(max3(tri->bbMax, p1thick), max3(p2thick, p3thick));
	tri->bbMin = min3(tri->bbMin, sidedropMin);
	tri->bbMax = max3(tri->bbMax, sidedropMax);
}
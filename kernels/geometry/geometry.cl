#ifndef __GEOMETRY__
#define __GEOMETRY__

#FILE:geometry/sdf.cl
#FILE:geometry/sphere.cl
#FILE:geometry/quad.cl
#FILE:geometry/aabb.cl
#FILE:geometry/triangle.cl
#FILE:geometry/bvh.cl

bool sampleDirect(
	const Mesh* mesh, 
	const float3* p, 
	LightSample* lightSample, 
	RNG_SEED_PARAM
) {
#ifdef __SPHERE__
	if (mesh->t & SPHERE)
#else
	if (false)
#endif
	{
		return sphere_sampleDirect(mesh, p, lightSample, RNG_SEED_VALUE);
	}
#ifdef __QUAD__
	else if (mesh->t & QUAD) {
		return quad_sampleDirect(mesh, p, lightSample, RNG_SEED_VALUE);
	}
#endif

	return false;
}

float directPdf(const Mesh* mesh, const float3* dir, const float3* p) {
	float dPdf = 0.0f;

#ifdef __SPHERE__
	if (mesh->t & SPHERE)
#else
	if (false)
#endif
	{
		dPdf = sphere_directPdf(mesh, p);
	}
#ifdef __QUAD__
	else if (mesh->t & QUAD) {
		dPdf = quad_directPdf(dir, mesh, p);
	}
#endif

	return dPdf;
}

#endif

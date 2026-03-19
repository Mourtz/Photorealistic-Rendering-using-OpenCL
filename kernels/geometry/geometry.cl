#ifndef __GEOMETRY__
#define __GEOMETRY__

#FILE:geometry/sdf.cl
#FILE:geometry/sphere.cl
#FILE:geometry/quad.cl
#FILE:geometry/aabb.cl
#FILE:geometry/triangle.cl
#FILE:geometry/bvh.cl

bool sampleDirectScene(
	const Scene* scene,
	const uint mesh_id,
	const float3* p,
	LightSample* lightSample,
	RNG_SEED_PARAM
) {
	const uint mesh_type = scene->mesh_type[mesh_id];

#ifdef __SPHERE__
	if (mesh_type & SPHERE){
		return sphere_sampleDirect(scene->mesh_pos[mesh_id].xyz, scene->mesh_joker[mesh_id].x, p, lightSample, RNG_SEED_VALUE);
	}
#else
	if (false) {}
#endif
#ifdef __QUAD__
	else if (mesh_type & QUAD) {
		float16 j = scene->mesh_joker[mesh_id];
		return quad_sampleDirect(j.s012, j.s345, j.s678, j.s9ab, j.sC, p, lightSample, RNG_SEED_VALUE);
	}
#endif

	return false;
}

float directPdfScene(const Scene* scene, const uint mesh_id, const float3* dir, const float3* p) {
	const uint mesh_type = scene->mesh_type[mesh_id];
	float dPdf = 0.0f;

#ifdef __SPHERE__
	if (mesh_type & SPHERE)
	{
		dPdf = sphere_directPdf(scene->mesh_pos[mesh_id].xyz, scene->mesh_joker[mesh_id].x, p);
	}
#else
	if (false){}
#endif
#ifdef __QUAD__
	else if (mesh_type & QUAD) {
		float16 j = scene->mesh_joker[mesh_id];
		dPdf = quad_directPdf(j.s012, j.s9ab, j.sC, dir, p);
	}
#endif

	return dPdf;
}

#endif

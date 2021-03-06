#if defined(SDF) && !defined(__SDF__)
#define __SDF__

/*----------------------------------- PRIMITIVES -----------------------------------*/
float sdSphere(const float3 p, const float s) {
	return fast_length(p) - s;
}

float sdBox(const float3 p, const float3 b) {
	float3 d = fabs(p) - b;
	return fmin(fmax(d.x, fmax(d.y, d.z)), 0.0f) + fast_length(fmax(d, 0.0f));
}

float udBox(const float3 p, const float3 b) {
	return fast_length(fmax(fabs(p) - b, 0.0f));
}

float udRoundBox(const float3 p, const float3 b, const float r){
	return fast_length(fmax(fabs(p) - b, 0.0f)) - r;
}

float sdPlane(float3 p, float4 n){
	return dot(p, n.xyz) + n.w;
}

float sdCylinder(const float3 p, const float r, const float height) {
	float d = fast_length(p.xz) - r;
	d = fmax(d, fabs(p.y) - height);
	return d;
}

float sdTorus( const float3 p, float2 t ){
	float2 q = (float2)(fast_length(p.xz)-t.x,p.y);
	return fast_length(q)-t.y;
}

/*----------------------------------- Map -----------------------------------*/

float s_map(const Mesh* sdf, const float3 pos) {
	const float3 sdf_center = pos - sdf->pos;

	if (sdf->t & SDF_SPHERE) {
		return sdSphere(sdf_center, sdf->joker.s0);
	}
	else if (sdf->t & SDF_BOX) {
		return sdBox(sdf_center, sdf->joker.s012);
	}
	else if (sdf->t & SDF_ROUND_BOX) {
		return udRoundBox(sdf_center, sdf->joker.s012, sdf->joker.s3);
	}
	else if (sdf->t & SDF_PLANE) {
		return sdPlane(sdf_center, sdf->joker.s0123);
	}

	return INF;
}

float map(__constant Mesh* meshes, const float tmin, const float3 pos, int* mesh_id, const uint* mesh_count) {

	float dist = tmin;

	const uint fl = mesh_count[0] + mesh_count[1];

	for (uint i = mesh_count[0]; i < fl; ++i) {
		Mesh sdf = meshes[i]; /* local copy */
		float temp_dist = s_map(&sdf, pos);

		if (temp_dist < dist) {
			dist = temp_dist;
			*mesh_id = i;
		}
	}

	return dist;
}

float3 calcNormal(const Mesh* mesh, const float3 pos) {
	const float3 eps = (float3)(EPS*2.0f, 0.0f, 0.0f);

	return normalize((float3)(
		s_map(mesh, pos + eps.xyy) - s_map(mesh, pos - eps.xyy),
		s_map(mesh, pos + eps.yxy) - s_map(mesh, pos - eps.yxy),
		s_map(mesh, pos + eps.yyx) - s_map(mesh, pos - eps.yyx))
	);
}

/*----------------------------------- Raymarching -----------------------------------*/

bool shadow_sdf(__constant Mesh* meshes, Ray* ray, const uint* mesh_count) {
	float t = EPS * 100.0f;
	int id;

	for (int i = 0; i < SHADOW_MARCHING_STEPS; ++i) {
		float h = fabs(map(meshes, ray->t, (ray->origin + ray->dir * t), &id, mesh_count));
		t += h;
		if (h < EPS || t > ray->t) break;
	}

	return (t <= ray->t);
}

/* sdf intersection */
bool intesect_sdf(__constant Mesh* meshes, Ray* ray, int* mesh_id, const uint* mesh_count) {
	float t = EPS*10.0f;
	int id;

	for (int i = 0; i < MARCHING_STEPS; ++i) {
		float h = fabs(map(meshes, ray->t, (ray->origin + ray->dir * t), &id, mesh_count));
		if (h < EPS || t > ray->t) break;
		t += h;
	}

	if (t > ray->t) return false;

	ray->t = t;
	*mesh_id = id;
	return true;
}

#endif
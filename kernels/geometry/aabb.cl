/* AABB intersection */
const bool intersectBox(
	const Ray* ray, const float3* invDir,
	const float4 bbMin, const float4 bbMax,
	float* tNear, float* tFar
) {
	const float3 t1 = (bbMin.xyz - ray->origin) * (*invDir);
	float3 tMax = (bbMax.xyz - ray->origin) * (*invDir);
	const float3 tMin = fmin(t1, tMax);
	tMax = fmax(t1, tMax);

	*tNear = fmax(fmax(tMin.x, tMin.y), tMin.z);
	*tFar = fmin(fmin(tMax.x, tMax.y), fmin(tMax.z, *tFar));

	return (*tNear <= *tFar);
}

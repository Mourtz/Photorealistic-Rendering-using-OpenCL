#ifndef __T_BASE__
#define __T_BASE__

SurfaceScatterEvent makeLocalScatterEvent(Ray* ray, const Scene* scene) {
	TangentFrame frame = createTangentFrame(&ray->normal);
	return (SurfaceScatterEvent){ toLocal(&frame, -ray->dir) , (float3)(0.0), (float3)(1.0), 1.0, frame };
}

bool sample_BSDF(
	Ray* ray, SurfaceScatterEvent* event,
	const Material* mat,
	uint* seed0, uint* seed1
){
	/*-------------------- DIFFUSE --------------------*/
#ifdef DIFF
	if (mat->t & DIFF)
#else
	if (false)
#endif
	{
		LambertBSDF(ray, event, mat, seed0, seed1);
	}
	/*-------------------- CONDUCTOR --------------------*/
#ifdef COND
	else if (mat.t & COND)
	{
		if (!Conductor(ray, &surfaceEvent, &mat, seed0, seed1)) {
			return false;
		}
	}
#endif

	return true;
}


bool handleSurface(Ray* ray, SurfaceScatterEvent* event, const Scene* scene) {
	ray->origin = ray->pos + event->frame.normal * EPS;
	ray->dir = toGlobal(&event->frame, event->wo);

	return true;
}
#endif

typedef struct {
	float3 position;
	float3 view;
	float3 up;
	float2 resolution;
	float2 fov;
	float apertureRadius;
	float focalDistance;
} Camera;

Ray createCamRay(const int x_coord, const int y_coord, const int width, const int height, __constant Camera* cam, const uint* seed0, const uint* seed1) {

	/* create a local coordinate frame for the camera */
	float3 rendercamview = cam->view; rendercamview = normalize(rendercamview);
	float3 rendercamup = cam->up; rendercamup = normalize(rendercamup);
	float3 horizontalAxis = cross(rendercamview, rendercamup); horizontalAxis = normalize(horizontalAxis);
	float3 verticalAxis = cross(horizontalAxis, rendercamview); verticalAxis = normalize(verticalAxis);

	float3 middle = cam->position + rendercamview;
	float3 horizontal = horizontalAxis * tan(cam->fov.x * 0.5f * (PI / 180));
	float3 vertical = verticalAxis * tan(cam->fov.y * -0.5f * (PI / 180));

	unsigned int x = x_coord;
	unsigned int y = y_coord;

	int pixelx = x_coord;
	int pixely = height - y_coord - 1;

	float sx = (float)pixelx / (width - 1.0f);
	float sy = (float)pixely / (height - 1.0f);

	float3 pointOnPlaneOneUnitAwayFromEye = middle + (horizontal * ((2 * sx) - 1)) + (vertical * ((2 * sy) - 1));
	float3 pointOnImagePlane = cam->position + ((pointOnPlaneOneUnitAwayFromEye - cam->position) * cam->focalDistance); /* cam->focalDistance */

	float3 aperturePoint;

	/* if aperture is non-zero (aperture is zero for pinhole camera), pick a random point on the aperture/lens */
	if (cam->apertureRadius > 0.00001f) {

		float random1 = get_random(seed0, seed1);
		float random2 = get_random(seed1, seed0);

		float angle = 2 * PI * random1;
		float distance = cam->apertureRadius * sqrt(random2);
		float apertureX = cos(angle) * distance;
		float apertureY = sin(angle) * distance;

		aperturePoint = cam->position + (horizontalAxis * apertureX) + (verticalAxis * apertureY);
	}
	else aperturePoint = cam->position;

	float3 apertureToImagePlane = normalize(pointOnImagePlane - aperturePoint);


	/* create camera ray*/
	Ray ray;
	ray.origin = aperturePoint;
	ray.dir = apertureToImagePlane;

	return ray;
}
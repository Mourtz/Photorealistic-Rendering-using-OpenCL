#ifndef __ENVMAP_IS__
#define __ENVMAP_IS__

// Binary search in a CDF array of `n` elements.
static int cdf_sample(const __global float* cdf, int n, float xi)
{
	int lo = 0, hi = n - 1;
	while (lo < hi) {
		int mid = (lo + hi) >> 1;
		if (cdf[mid] < xi)
			lo = mid + 1;
		else
			hi = mid;
	}
	return lo;
}

// Evaluate the solid-angle PDF of a direction under the env-map IS distribution.
float envMapPdf(float3 dir, const EnvMapIS* envIS)
{
	if (!envIS) return 0.0f;

	// Direction → equirectangular UV in [0,1]
	float phi   = atan2(dir.z, dir.x);
	float theta = acos(clamp(dir.y, -1.0f, 1.0f));
	float u = (phi * (float)(M_1_PI) * 0.5f) + 0.5f;
	float v = theta * (float)(M_1_PI);

	int ix = clamp((int)(u * envIS->width),  0, envIS->width  - 1);
	int iy = clamp((int)(v * envIS->height), 0, envIS->height - 1);

	return envIS->pdf[iy * envIS->width + ix];
}

// Sample a direction from the env-map 2D CDF.
float3 envMapSample(float2 rand2, const EnvMapIS* envIS, float* pdf_out)
{
	int iy = cdf_sample(envIS->marginalCdf, envIS->height, rand2.x);

	const __global float* condRow = envIS->conditionalCdf + iy * envIS->width;
	int ix = cdf_sample(condRow, envIS->width, rand2.y);

	float u = ((float)ix + 0.5f) / (float)envIS->width;
	float v = ((float)iy + 0.5f) / (float)envIS->height;

	float phi   = (u * 2.0f - 1.0f) * (float)M_PI;
	float theta = v * (float)M_PI;

	float sin_theta = sin(theta);
	float cos_theta = cos(theta);
	float sin_phi   = sin(phi);
	float cos_phi   = cos(phi);

	*pdf_out = envIS->pdf[iy * envIS->width + ix];

	return (float3)(sin_theta * cos_phi, cos_theta, sin_theta * sin_phi);
}

#endif // __ENVMAP_IS__

#ifndef __BVH__
#define __BVH__

void intersectFace(
	const Scene* scene, Ray* ray,
	const int faceIndex, float* t,
	const float tNear, float tFar
) {
	const float3 normal = checkFaceIntersection(scene, ray, faceIndex, t, tNear, tFar);

	if (ray->t > *t) {
		ray->normal = normal;
		// ray->hitFace = faceIndex;
		ray->t = *t;
	}
}

void intersectFaces(const Scene* scene, Ray* ray, const bvhNode* node, const float tNear, float tFar) {
	float t = INF;

	intersectFace(scene, ray, (int)node->bbMin.w, &t, tNear, tFar);

	if (node->bbMax.w == -1) {
		return;
	}

	intersectFace(scene, ray, node->bbMax.w, &t, tNear, tFar);
}

void traverseShadows(const Scene* scene, Ray* ray) {
	const float tLight = ray->t;
	const float3 invDir = native_recip(ray->dir);
	int index = 1;

	do {
		const bvhNode node = scene->bvh[index];
		int currentIndex = index;

		// @see traverse() for an explanation.
		index = (node.bbMin.w <= -1.0f) ? (int)node.bbMax.w : currentIndex + 1;

		float tNear = 0.0f;
		float tFar = INFINITY;

		bool isNodeHit = (
			intersectBox(ray, &invDir, node.bbMin, node.bbMax, &tNear, &tFar) &&
			tFar > EPS
			);

		if (!isNodeHit) {
			continue;
		}

		index = currentIndex + 1;

		// Skip the next left child node.
		if (node.bbMin.w == -2.0f) {
			index++;
		}

		// Node is leaf node. Test faces.
		if (node.bbMin.w >= 0.0f) {
			intersectFaces(scene, ray, &node, tNear, tFar);

			// It's enough to know that something blocks the way. It doesn't matter what or where.
			// TODO: It *does* matter what and where, if the material has transparency.
			if (ray->t < tLight) {
				break;
			}
		}
	} while (index > 0 && index < scene->NUM_NODES);
}

void traverse(const Scene* scene, Ray* ray) {
	const float3 invDir = native_recip(ray->dir);
	int index = 1;

	do {
		const bvhNode node = scene->bvh[index];
		int currentIndex = index;

		index = (node.bbMin.w <= -1.0f) ? (int)node.bbMax.w : currentIndex + 1;

		float tNear = 0.0f;
		float tFar = INF;

		bool isNodeHit = (
			intersectBox(ray, &invDir, node.bbMin, node.bbMax, &tNear, &tFar) &&
			tFar > EPS && ray->t > tNear
		);

		if (!isNodeHit) {
			continue;
		}

		index = currentIndex + 1;

		if (node.bbMin.w >= 0.0f) {
			intersectFaces(scene, ray, &node, tNear, tFar);
		}
	} while (index > 0 && index < scene->NUM_NODES);
}

#endif
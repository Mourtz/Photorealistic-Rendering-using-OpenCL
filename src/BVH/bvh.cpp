#include <BVH/bvh.h>

#include <Math/linear_algebra.h>
#include <Model/model_loader.h>
#include <bvh/bvh.hpp>
#include <bvh/binned_sah_builder.hpp>
#include <bvh/sweep_sah_builder.hpp>
#include <bvh/triangle.hpp>
#include <bvh/ray.hpp>

#include <bvh/single_ray_traverser.hpp>
#include <iostream>

#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>

using Vector3 = bvh::Vector3<Scalar>;
using Ray = bvh::Ray<Scalar>;
using BoundingBox = bvh::BoundingBox<Scalar>;

namespace CL_RAYTRACER
{
    struct cl_Mesh
    {
        std::vector<cl_float3> position;
        std::vector<cl_float3> normal;
        std::vector<cl_float2> uv;
        std::vector<cl_uchar3> color;
    };

    BVH::BVH(const std::shared_ptr<IO::ModelLoader> &ml) : bvh(std::make_unique<Bvh>()),
                                                                   model_loader(ml)
    {
        buildTree(ml);
    }

    BVH::~BVH()
    {
        bvh.reset();
        triangles.clear();
    }

    void BVH::buildTree(const std::shared_ptr<IO::ModelLoader> &ml)
    {
        std::cout << "[BVH] Building tree..." << std::endl;
        double t0 = glfwGetTime();

        auto &scene = ml->getFaces();
        for (const auto &mesh : scene->meshes)
        {
            for (const auto &face : mesh.faces)
            {
                triangles.emplace_back(
                    Vector3(face.points[0].pos.x, face.points[0].pos.y, face.points[0].pos.z), Vector3(face.points[1].pos.x, face.points[1].pos.y, face.points[1].pos.z), Vector3(face.points[2].pos.x, face.points[2].pos.y, face.points[2].pos.z));
            }
        }

        auto [bboxes, centers] = bvh::compute_bounding_boxes_and_centers(triangles.data(), triangles.size());
        auto global_bbox = bvh::compute_bounding_boxes_union(bboxes.get(), triangles.size());

        // bvh::BinnedSahBuilder<Bvh, 64> builder(*bvh);
        bvh::SweepSahBuilder<Bvh> builder(*bvh);
        builder.build(global_bbox, bboxes.get(), centers.get(), triangles.size());

        std::cout << "[BVH] Finished builing BVH(node_count = " << bvh->node_count << ") in "
                  << (glfwGetTime() - t0) << "seconds" << std::endl;
    }

    std::unique_ptr<std::vector<cl_ulong>> BVH::GetPrimitiveIndices() const {
        std::unique_ptr<std::vector<cl_ulong>> res = std::make_unique<std::vector<cl_ulong>>();
        for(size_t i = 0; i < triangles.size(); ++i){
            res->emplace_back(bvh->primitive_indices[i]);
        }
        return res;
    }

    std::unique_ptr<std::vector<cl_BVHnode>> BVH::PrepareData() const
    {
        std::unique_ptr<std::vector<cl_BVHnode>> res = std::make_unique<std::vector<cl_BVHnode>>();
        for (int i = 0; i < bvh->node_count; ++i)
        {
            const Bvh::Node &node = bvh->nodes[i];
            
            cl_BVHnode bb;
            bb.bounds[0] = node.bounds[0];
            bb.bounds[1] = node.bounds[1];
            bb.bounds[2] = node.bounds[2];
            bb.bounds[3] = node.bounds[3];
            bb.bounds[4] = node.bounds[4];
            bb.bounds[5] = node.bounds[5];
            bb.is_leaf = node.is_leaf;
            bb.first_child_or_primitive = node.first_child_or_primitive;
            bb.primitive_count = node.primitive_count;
            res->push_back(bb);
        }
        return res;
    }

} // namespace CL_RAYTRACER
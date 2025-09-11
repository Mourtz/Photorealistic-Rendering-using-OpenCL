#include <BVH/bvh.h>

#include <Math/linear_algebra.h>
#include <Model/model_loader.h>

#include <bvh/v2/bvh.h>
#include <bvh/v2/vec.h>
#include <bvh/v2/ray.h>
#include <bvh/v2/node.h>
#include <bvh/v2/default_builder.h>
#include <bvh/v2/thread_pool.h>
#include <bvh/v2/executor.h>
#include <bvh/v2/stack.h>
#include <bvh/v2/tri.h>

#include <iostream>
#include <functional>

#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>

using Scalar  = float;
using Vec3    = bvh::v2::Vec<Scalar, 3>;
using BBox    = bvh::v2::BBox<Scalar, 3>;
using Tri     = bvh::v2::Tri<Scalar, 3>;
using Node    = bvh::v2::Node<Scalar, 3>;
using Bvh     = bvh::v2::Bvh<Node>;
using Ray     = bvh::v2::Ray<Scalar, 3>;

using PrecomputedTri = bvh::v2::PrecomputedTri<Scalar>;

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
                    Vec3(face.points[0].pos.x, face.points[0].pos.y, face.points[0].pos.z), Vec3(face.points[1].pos.x, face.points[1].pos.y, face.points[1].pos.z), Vec3(face.points[2].pos.x, face.points[2].pos.y, face.points[2].pos.z));
            }
        }

        bvh::v2::ThreadPool thread_pool;
        bvh::v2::ParallelExecutor executor(thread_pool);

        // Get triangle centers and bounding boxes (required for BVH builder)
        std::vector<BBox> bboxes(triangles.size());
        std::vector<Vec3> centers(triangles.size());
        executor.for_each(0, triangles.size(), [&] (size_t begin, size_t end) {
        for (size_t i = begin; i < end; ++i) {
            bboxes[i]  = triangles[i].get_bbox();
            centers[i] = triangles[i].get_center();
        }
        });

        typename bvh::v2::DefaultBuilder<Node>::Config config;
        config.quality = bvh::v2::DefaultBuilder<Node>::Quality::High;
        bvh = std::make_unique<Bvh>(bvh::v2::DefaultBuilder<Node>::build(thread_pool, bboxes, centers, config));

        double t1 = glfwGetTime();
        std::cout << "[BVH] Tree built in " << t1 - t0 << " seconds" << std::endl;
    }

    void BVH::calculateMissLinks(std::vector<uint32_t>& miss_links) const
    {
        miss_links.resize(bvh->nodes.size());
        
        // Use a recursive approach to calculate miss links
        // The miss link points to the next node to visit when the current node is missed
        std::function<void(uint32_t, uint32_t)> calculateMissLinksRecursive = 
            [&](uint32_t node_index, uint32_t parent_miss_link) {
            
            const Node& node = bvh->nodes[node_index];
            
            if (node.is_leaf()) {
                miss_links[node_index] = parent_miss_link;
                return;
            }
            
            uint32_t left_child = node.index.first_id();
            uint32_t right_child = left_child + 1;
            
            miss_links[node_index] = parent_miss_link;
            
            calculateMissLinksRecursive(left_child, right_child);
            calculateMissLinksRecursive(right_child, parent_miss_link);
        };
        
        calculateMissLinksRecursive(0, UINT32_MAX);
    }

    std::unique_ptr<std::vector<cl_ulong>> BVH::GetPrimitiveIndices() const {
        std::unique_ptr<std::vector<cl_ulong>> res = std::make_unique<std::vector<cl_ulong>>();
        for(size_t i = 0; i < triangles.size(); ++i){
            res->emplace_back(bvh->prim_ids[i]);
        }
        return res;
    }

    std::unique_ptr<std::vector<cl_BVHnode>> BVH::PrepareData() const
    {
        std::unique_ptr<std::vector<cl_BVHnode>> res = std::make_unique<std::vector<cl_BVHnode>>();
        
        std::vector<uint32_t> miss_links(bvh->nodes.size());
        calculateMissLinks(miss_links);
        
        for (int i = 0; i < bvh->nodes.size(); ++i)
        {
            const Node &node = bvh->nodes[i];
            
            cl_BVHnode bb;
            bb.bounds[0] = node.bounds[0];
            bb.bounds[1] = node.bounds[1];
            bb.bounds[2] = node.bounds[2];
            bb.bounds[3] = node.bounds[3];
            bb.bounds[4] = node.bounds[4];
            bb.bounds[5] = node.bounds[5];
            bb.is_leaf = node.is_leaf();
            bb.first_child_or_primitive = node.index.first_id();
            bb.primitive_count = node.index.prim_count();
            bb.miss_link = miss_links[i];
            res->push_back(bb);
        }
        return res;
    }

} // namespace CL_RAYTRACER
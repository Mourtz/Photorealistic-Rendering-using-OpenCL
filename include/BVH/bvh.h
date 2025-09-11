#pragma once

#include <vector>
#include <memory>
#include <CL/cl_platform.h>

#include <bvh/v2/bvh.h>
#include <bvh/v2/vec.h>
#include <bvh/v2/ray.h>
#include <bvh/v2/node.h>
#include <bvh/v2/default_builder.h>
#include <bvh/v2/thread_pool.h>
#include <bvh/v2/executor.h>
#include <bvh/v2/stack.h>
#include <bvh/v2/tri.h>

using Scalar  = float;
using Vec3    = bvh::v2::Vec<Scalar, 3>;
using BBox    = bvh::v2::BBox<Scalar, 3>;
using Tri     = bvh::v2::Tri<Scalar, 3>;
using Node    = bvh::v2::Node<Scalar, 3>;
using Bvh     = bvh::v2::Bvh<Node>;
using Ray     = bvh::v2::Ray<Scalar, 3>;

using PrecomputedTri = bvh::v2::PrecomputedTri<Scalar>;

//-------------------- Logic ---------------------
namespace CL_RAYTRACER
{
    struct cl_Mesh;
    struct cl_BVHnode
    {
        float bounds[6];
        unsigned int first_child_or_primitive;
        unsigned int primitive_count;
        bool is_leaf;
        unsigned int miss_link;
    };

    namespace IO
    {
        class ModelLoader;
    }
} // namespace CL_RAYTRACER

namespace CL_RAYTRACER
{
    class BVH
    {
    private:
        std::vector<Tri> triangles;
        std::unique_ptr<Bvh> bvh;
        const std::shared_ptr<IO::ModelLoader> model_loader;

        void calculateMissLinks(std::vector<uint32_t>& miss_links) const;

    public:
        BVH(const std::shared_ptr<IO::ModelLoader> &ml);
        ~BVH();

        void buildTree(const std::shared_ptr<IO::ModelLoader> &ml);

        std::unique_ptr<std::vector<cl_ulong>> GetPrimitiveIndices() const;

        std::unique_ptr<std::vector<cl_BVHnode>> PrepareData() const;
    };
} // namespace CL_RAYTRACER
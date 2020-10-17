#pragma once

#include <vector>
#include <memory>
#include <CL/cl_platform.h>

//------------ fwd declarations -------------------
namespace bvh
{
    template <typename Scalar>
    struct Triangle;
    template <typename Scalar>
    struct Bvh;
} // namespace bvh

using Scalar = float;
using Triangle = bvh::Triangle<float>;
using Bvh = bvh::Bvh<float>;

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
        std::vector<Triangle> triangles;
        std::unique_ptr<Bvh> bvh;
        const std::shared_ptr<IO::ModelLoader> model_loader;

    public:
        BVH(const std::shared_ptr<IO::ModelLoader> &ml);
        ~BVH();

        void buildTree(const std::shared_ptr<IO::ModelLoader> &ml);

        std::unique_ptr<std::vector<cl_ulong>> GetPrimitiveIndices() const;

        std::unique_ptr<std::vector<cl_BVHnode>> PrepareData() const;
    };
} // namespace CL_RAYTRACER
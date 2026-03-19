#pragma once

#include <CL/opencl.hpp>

// Must mirror the RenderParams typedef in kernels/header.cl exactly.
// Packed into a single cl_uint:
//   bit  0   : enableNEE
//   bit  1   : enableMIS
//   bit  2   : enableRIS
//   bit  3   : enableEnvMapIS
//   bits 8-12: risM-1  (encodes 1..32 as 0..31)

typedef cl_uint RenderParams;

inline RenderParams makeRenderParams(bool nee, bool mis, bool ris, bool envIS, int risM) {
    return (nee   ? 1u : 0u)
         | (mis   ? 2u : 0u)
         | (ris   ? 4u : 0u)
         | (envIS ? 8u : 0u)
         | (static_cast<cl_uint>(risM - 1) << 8u);
}

inline bool rpNEE     (RenderParams p) { return (p & 1u) != 0u; }
inline bool rpMIS     (RenderParams p) { return (p & 2u) != 0u; }
inline bool rpRIS     (RenderParams p) { return (p & 4u) != 0u; }
inline bool rpEnvIS   (RenderParams p) { return (p & 8u) != 0u; }
inline int  rpRisM    (RenderParams p) { return static_cast<int>((p >> 8u) & 0x1Fu) + 1; }

inline void rpSetNEE  (RenderParams& p, bool v) { p = v ? (p | 1u) : (p & ~1u); }
inline void rpSetMIS  (RenderParams& p, bool v) { p = v ? (p | 2u) : (p & ~2u); }
inline void rpSetRIS  (RenderParams& p, bool v) { p = v ? (p | 4u) : (p & ~4u); }
inline void rpSetEnvIS(RenderParams& p, bool v) { p = v ? (p | 8u) : (p & ~8u); }
inline void rpSetRisM (RenderParams& p, int  m) { p = (p & ~(0x1Fu << 8u)) | (static_cast<cl_uint>(m - 1) << 8u); }

struct RenderSettings {
    // Default: NEE=on, MIS=on, RIS=off, EnvIS=off, risM=8
    RenderParams params = makeRenderParams(true, true, false, false, 8);

    bool hasEnvMap = false;

    float exposure = 1.0f;

    // Firefly clamping: max per-sample luminance (0 = disabled)
    float clampThreshold = 10.0f;
    bool  enableClamping  = true;

    // Debug / view overlay (reserved)
    int viewMode = 0;
};

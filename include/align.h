#ifndef __ALIGN_H___
#define __ALIGN_H___

#if defined(_MSC_VER)
#define ALIGN(x) __declspec(align(x))
#elif defined(__GNUC__) || defined(__MINGW32__)
#define ALIGN(x) __attribute__((aligned(x)))
#elif defined(__OPENCL_C_VERSION__)
#define ALIGN(x) __attribute__((aligned(x)))
#else
#error Alignment macro not set.
#endif

#endif  // __ALIGN_H___

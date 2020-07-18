#include <Math/linear_algebra.h>

template <>
float Vector<float>::lengthsq3(){return sqrtf(x * x + y * y + z * z);}

template <>
float Vector<float>::lengthsq4(){return sqrtf(x * x + y * y + z * z + w * w);}

template <>
void Vector<float>::normalize(){float norm = sqrtf(x * x + y * y + z * z); *this = *this / norm; }
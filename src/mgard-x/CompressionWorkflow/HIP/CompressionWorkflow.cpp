/*
 * Copyright 2021, Oak Ridge National Laboratory.
 * MGARD-X: MultiGrid Adaptive Reduction of Data Portable across GPUs and CPUs
 * Author: Jieyang Chen (chenj3@ornl.gov)
 * Date: December 1, 2021
 */

#define MGARDX_COMPILE_HIP
#include "mgard-x/CompressionWorkflow.hpp"

#include <iostream>

#include <chrono>
namespace mgard_x {

#define KERNELS(D, T)                                        \
  template Array<1, unsigned char, HIP> compress<D, T, HIP>(\
                                Handle<D, T, HIP> &handle, Array<D, T, HIP> &in_array,\
                                 enum error_bound_type type, T tol, T s);  \
  template Array<D, T, HIP> decompress<D, T, HIP>(Handle<D, T, HIP> &handle,\
                       Array<1, unsigned char, HIP> &compressed_array);

KERNELS(1, double)
KERNELS(1, float)
KERNELS(2, double)
KERNELS(2, float)
KERNELS(3, double)
KERNELS(3, float)
KERNELS(4, double)
KERNELS(4, float)
KERNELS(5, double)
KERNELS(5, float)
#undef KERNELS

} // namespace mgard_x
#undef MGARDX_COMPILE_HIP
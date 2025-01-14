/*
 * Copyright 2021, Oak Ridge National Laboratory.
 * MGARD-X: MultiGrid Adaptive Reduction of Data Portable across GPUs and CPUs
 * Author: Jieyang Chen (chenj3@ornl.gov)
 * Date: December 1, 2021
 */

#define MGARDX_COMPILE_CUDA
#include "mgard-x/RuntimeX/RuntimeX.h"

namespace mgard_x {

int DeviceRuntime<CUDA>::curr_dev_id = 0;
DeviceQueues<CUDA> DeviceRuntime<CUDA>::queues;
DeviceSpecification<CUDA> DeviceRuntime<CUDA>::DeviceSpecs;

bool DeviceRuntime<CUDA>::SyncAllKernelsAndCheckErrors = false;
bool MemoryManager<CUDA>::ReduceMemoryFootprint = true;
bool DeviceRuntime<CUDA>::TimingAllKernels = false;
bool DeviceRuntime<CUDA>::PrintKernelConfig = false;

KernelConfigs<CUDA> AutoTuner<CUDA>::kernelConfigs;
AutoTuningTable<CUDA> AutoTuner<CUDA>::autoTuningTable;
bool AutoTuner<CUDA>::ProfileKernels = false;

template <> bool deviceAvailable<CUDA>() {
  return DeviceRuntime<CUDA>::GetDeviceCount() > 0;
}

} // namespace mgard_x
#undef MGARDX_COMPILE_CUDA
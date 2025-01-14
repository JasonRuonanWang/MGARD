/*
 * Copyright 2021, Oak Ridge National Laboratory.
 * MGARD-X: MultiGrid Adaptive Reduction of Data Portable across GPUs and CPUs
 * Author: Jieyang Chen (chenj3@ornl.gov)
 * Date: December 1, 2021
 */
#include "DataTypes.h"

#include "DataStructures/Array.h"
#include "Utilities/Message.h"
#include "Utilities/Timer.hpp"

#ifndef MGARD_X_RUNTIME_X_PUBLIC_H
#define MGARD_X_RUNTIME_X_PUBLIC_H

namespace mgard_x {

template <typename DeviceType> bool deviceAvailable();
}

#endif
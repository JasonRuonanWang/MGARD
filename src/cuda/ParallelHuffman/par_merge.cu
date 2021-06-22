#include <float.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "cuda/ParallelHuffman/par_merge.cuh"
#include <cooperative_groups.h>

using namespace cooperative_groups;

#define MAX(X, Y) (((X) > (Y)) ? (X) : (Y))
#define MIN(X, Y) (((X) < (Y)) ? (X) : (Y))
// Mathematically correct modulo
#define MOD(a, b) ((((a) % (b)) + (b)) % (b))

/* MERGETYPE
 * Performs <runs> merges of two sorted pseudorandom <vec_t> arrays of length
 * <size> Times the runs and reports on the average time Checks the output of
 * each merge for correctness
 */
#define PADDING 1024

// clang-format off
template <typename F>
__device__ void parMerge(
    F* copyFreq,    int* copyIndex,  int* copyIsLeaf,   int  cStart,    int cEnd,
    F* iNodesFreq,  int  iStart,     int  iEnd,         int  iNodesCap,
    F* tempFreq,    int* tempIndex,  int* tempIsLeaf,   int& tempLength,
    uint32_t* diagonal_path_intersections, int blocks,  int  threads,
    /* Shared Memory */
    int32_t& x_top, int32_t& y_top,  int32_t& x_bottom, int32_t& y_bottom,
    int32_t& found, int32_t* oneorzero)
{
  // clang-format on
  auto current_grid = this_grid();
  current_grid.sync();
  tempLength = (cEnd - cStart) + MOD(iEnd - iStart, iNodesCap);

  if (tempLength == 0)
    return;

  // Perform the global diagonal intersection serach to divide work among SMs
  cudaWorkloadDiagonals<F>(copyFreq, copyIndex, copyIsLeaf, cStart, cEnd, //
                           iNodesFreq, iStart, iEnd, iNodesCap,           //
                           diagonal_path_intersections,                   //
                           x_top, y_top, x_bottom, y_bottom, found, oneorzero);
  current_grid.sync();

  // Merge between global diagonals independently on each block
  cudaMergeSinglePath<F>(copyFreq, copyIndex, copyIsLeaf, cStart, cEnd, //
                         iNodesFreq, iStart, iEnd, iNodesCap,           //
                         diagonal_path_intersections,                   //
                         tempFreq, tempIndex, tempIsLeaf, tempLength);
  current_grid.sync();
}

/* CUDAWORKLOADDIAGONALS
 * Performs a 32-wide binary search on one glboal diagonal per block to find the
 * intersection with the path. This divides the workload into independent merges
 * for the next step
 */
// clang-format off
template <typename F>
__device__ void cudaWorkloadDiagonals(
    F*  copyFreq,   int* copyIndex, int* copyIsLeaf,
    int cStart,     int  cEnd,
    F*  iNodesFreq,
    int iStart,     int  iEnd,      int  iNodesCap,
    uint32_t* diagonal_path_intersections,
    /* Shared Memory */
    int32_t& x_top, int32_t& y_top, int32_t& x_bottom, int32_t& y_bottom,
    int32_t& found, int32_t* oneorzero)
{
  // clang-format on
  uint32_t A_length = cEnd - cStart;
  uint32_t B_length = MOD(iEnd - iStart, iNodesCap);
  // Calculate combined index around the MergePath "matrix"
  int32_t combinedIndex =
      ((uint64_t)blockIdx.x * ((uint64_t)A_length + (uint64_t)B_length)) /
      (uint64_t)gridDim.x;
  /*
  __shared__ int32_t x_top, y_top, x_bottom, y_bottom,  found;
  __shared__ int32_t oneorzero[32];
  */
  int threadOffset = threadIdx.x - 16;

  if (threadIdx.x < 32) {
    // Figure out the coordinates of our diagonal
    if (A_length >= B_length) {
      x_top = MIN(combinedIndex, A_length);
      y_top = combinedIndex > A_length ? combinedIndex - (A_length) : 0;
      x_bottom = y_top;
      y_bottom = x_top;
    } else {
      y_bottom = MIN(combinedIndex, B_length);
      x_bottom = combinedIndex > B_length ? combinedIndex - (B_length) : 0;
      y_top = x_bottom;
      x_top = y_bottom;
    }
  }

  // if (threadIdx.x == 0) {
  //    printf("Diagonal block %d: (%d, %d) to (%d, %d)\n", blockIdx.x, x_top,
  //    y_top, x_bottom, y_bottom);
  //}

  found = 0;

  // Search the diagonal
  while (!found) {
    // Update our coordinates within the 32-wide section of the diagonal
    int32_t current_x = x_top - ((x_top - x_bottom) >> 1) - threadOffset;
    int32_t current_y = y_top + ((y_bottom - y_top) >> 1) + threadOffset;
    int32_t getfrom_x = current_x + cStart - 1;
    // Below statement is a more efficienD, Tivmodless version of the following
    // int32_t getfrom_y = MOD(iStart + current_y, iNodesCap);
    int32_t getfrom_y = iStart + current_y;

    if (threadIdx.x < 32) {
      if (getfrom_y >= iNodesCap)
        getfrom_y -= iNodesCap;

      // Are we a '1' or '0' with respect to A[x] <= B[x]
      if (current_x > (int32_t)A_length or current_y < 0) {
        oneorzero[threadIdx.x] = 0;
      } else if (current_y >= (int32_t)B_length || current_x < 1) {
        oneorzero[threadIdx.x] = 1;
      } else {
        oneorzero[threadIdx.x] =
            (copyFreq[getfrom_x] <= iNodesFreq[getfrom_y]) ? 1 : 0;
      }
    }

    __syncthreads();

    // If we find the meeting of the '1's and '0's, we found the
    // intersection of the path and diagonal
    if (threadIdx.x > 0 and                                    //
        threadIdx.x < 32 and                                   //
        (oneorzero[threadIdx.x] != oneorzero[threadIdx.x - 1]) //
    ) {
      found = 1;

      diagonal_path_intersections[blockIdx.x] = current_x;
      diagonal_path_intersections[blockIdx.x + gridDim.x + 1] = current_y;
    }

    __syncthreads();

    // Adjust the search window on the diagonal
    if (threadIdx.x == 16) {
      if (oneorzero[31] != 0) {
        x_bottom = current_x;
        y_bottom = current_y;
      } else {
        x_top = current_x;
        y_top = current_y;
      }
    }
    __syncthreads();
  }

  // Set the boundary diagonals (through 0,0 and A_length,B_length)
  if (threadIdx.x == 0 && blockIdx.x == 0) {
    diagonal_path_intersections[0] = 0;
    diagonal_path_intersections[gridDim.x + 1] = 0;
    diagonal_path_intersections[gridDim.x] = A_length;
    diagonal_path_intersections[gridDim.x + gridDim.x + 1] = B_length;
  }
}

// Serial merge
// clang-format off
template <typename F>
__device__ void merge(
    F*   copyFreq,   int* copyIndex, int* copyIsLeaf, int  cStart,    int  cEnd,
    F*   iNodesFreq, int  iStart,    int  iEnd,       int  iNodesCap,
    F*   tempFreq,   int* tempIndex, int* tempIsLeaf, int& tempLength)
{
  // clang-format on
  int len = 0;
  int iterCopy = cStart, iterINodes = iStart;

  while (iterCopy < cEnd && MOD(iEnd - iterINodes, iNodesCap) > 0) {
    if (copyFreq[iterCopy] <= iNodesFreq[iterINodes]) {
      tempFreq[len] = copyFreq[iterCopy];
      tempIndex[len] = copyIndex[iterCopy];
      tempIsLeaf[len] = copyIsLeaf[iterCopy];
      ++iterCopy;
    } else {
      tempFreq[len] = iNodesFreq[iterINodes];
      tempIndex[len] = iterINodes;
      tempIsLeaf[len] = 0;
      iterINodes = MOD(iterINodes + 1, iNodesCap);
    }
    ++len;
  }

  while (iterCopy < cEnd) {
    tempFreq[len] = copyFreq[iterCopy];
    tempIndex[len] = copyIndex[iterCopy];
    tempIsLeaf[len] = copyIsLeaf[iterCopy];
    ++iterCopy;
    ++len;
  }
  while (MOD(iEnd - iterINodes, iNodesCap) > 0) {
    tempFreq[len] = iNodesFreq[iterINodes];
    tempIndex[len] = iterINodes;
    tempIsLeaf[len] = 0;
    iterINodes = MOD(iterINodes + 1, iNodesCap);
    ++len;
  }

  tempLength = len;
}

/* CUDAMERGESINGLEPATH
 * Performs merge windows within a thread block from that block's global
 * diagonal intersection to the next
 */
#define K 512
#define PAD_SIZE 0

// clang-format off
template <typename F>
__device__ void cudaMergeSinglePath(
    F*  copyFreq,   int* copyIndex, int* copyIsLeaf,
    int cStart,     int  cEnd,
    F*  iNodesFreq,
    int iStart,     int  iEnd,      int  iNodesCap,
    uint32_t* diagonal_path_intersections,
    F*  tempFreq,   int* tempIndex, int* tempIsLeaf,
    int tempLength)
{
  // clang-format on
  // Temporary Code -- Serial Merge Per Block
  if (threadIdx.x == 0) {
    // Boundaries
    int x_block_top = diagonal_path_intersections[blockIdx.x];
    int y_block_top = diagonal_path_intersections[blockIdx.x + gridDim.x + 1];
    int x_block_stop = diagonal_path_intersections[blockIdx.x + 1];
    int y_block_stop = diagonal_path_intersections[blockIdx.x + gridDim.x + 2];

    // Actual indexes
    int x_start = x_block_top + cStart;
    int x_end = x_block_stop + cStart;
    int y_start = MOD(iStart + y_block_top, iNodesCap);
    int y_end = MOD(iStart + y_block_stop, iNodesCap);

    int offset = x_block_top + y_block_top;

    int dummy; // Unused result
    // TODO optimize serial merging of each partition
    merge(copyFreq, copyIndex, copyIsLeaf, x_start, x_end, //
          iNodesFreq, y_start, y_end, iNodesCap,           //
          tempFreq + offset, tempIndex + offset, tempIsLeaf + offset, dummy);
    if (0) {
      printf("block: %d x: %d %d, y: %d %d, contrib: %d\n", blockIdx.x,
             x_block_top, x_block_stop, y_block_top, y_block_stop, dummy);
    }
  }
}

// `unsigned int` instantiations
template __device__ void parMerge<unsigned int>(
    unsigned int *copyFreq, int *copyIndex, int *copyIsLeaf, int cStart,
    int cEnd, unsigned int *iNodesFreq, int iStart, int iEnd, int iNodesCap,
    unsigned int *tempFreq, int *tempIndex, int *tempIsLeaf, int &tempLength,
    uint32_t *diagonal_path_intersections, int blocks, int threads,
    /* Shared Memory */
    int32_t &x_top, int32_t &y_top, int32_t &x_bottom, int32_t &y_bottom,
    int32_t &found, int32_t *oneorzero);

template __device__ void
merge<unsigned int>(unsigned int *copyFreq, int *copyIndex, int *copyIsLeaf,
                    int cStart, int cEnd, unsigned int *iNodesFreq, int iStart,
                    int iEnd, int iNodesCap, unsigned int *tempFreq,
                    int *tempIndex, int *tempIsLeaf, int &tempLength);
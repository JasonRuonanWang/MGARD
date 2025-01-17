
# MGARD-X

MGARD-X is a portable implementation of the MGARD lossy compressor supporting various types of GPUs and CPUs.
## Supporting features
* **Data type:** Double and single precision floating-point data
* **Dimensions:** 1D-5D
* **Error-bound type:** L\_Inf error and L\_2 error
* **Error-bound mode:** Absoluate and relative
* **Data structure:** Uniform and non-uniform spaced Cartisan gird

## Portability
|Hardware|Portability|Tested processors|
|---|---|---|
|NVIDIA GPUs|Yes*|V100, RTX2080 Ti|
|AMD GPUs|Yes|MI-100, MI-250|
|x86 CPUs|Yes^|Intel CPUs, AMD CPUs|
|Power CPUs|Yes^|IMB Power9 CPUs|
|ARM CPUs|To be tested||
|Intel GPUs|Under development||
|Integrated GPUs|Under development||

*LZ4 lossless compressor is only avaialble to choose on NVIDIA GPUs. Portable version is under development.

^Serial execution is only avaialble for now. Multi-threaded version is under development.

## Interfaces

* **Command Line Inteface:** Full-featured command line executable for compression/decompression. 
* **High-level APIs:** Encapsulated all GPU-related details for easiest integration with user's program. Also, compressing metadata is being handled internally.
* **Low-level APIs:** Users can fully control different steps of compression (the preprocessing step, GPU buffers allocations, GPU compression kernel invokation, GPU-CPU data copy) for more fexiable and higher performance compression. Compressing metadata needs to be managed by users.

  

## Software requirements
### For NVIDIA GPUs

* CUDA 11.0+
* CMake 3.19+

### For AMD GPUs

* ROCm 4.5.0+
* CMake 3.21+

## Software dependencies 
* [NVCOMP v2.2.0][nvcomp] (for NVIDIA GPUs only)
* [ZSTD v1.5.0][zstd]
* [Protobuf v3.19.4][protobuf]

[nvcomp]: https://github.com/NVIDIA/nvcomp.git
[zstd]: https://github.com/facebook/zstd.git
[protobuf]: https://github.com/protocolbuffers/protobuf.git
## Configure and build
* **Option 1:** One-step configure and build scripts are available [here][build_scripts].
* **Option 2:** Manually confiugre and build with CMake

[build_scripts]:build_script
	
|CMake options|Value|Description|
|---|---|---|
|MGARD\_ENABLE\_CUDA|ON/OFF|Enable portable GPU compression/decompression with CUDA on NVIDIA GPUs|
|MGARD\_ENABLE\_HIP|ON/OFF|Enable portable GPU compression/decompression with HIP on AMD GPUs|
|MGARD\_ENABLE\_SERIAL|ON/OFF|Enable portable serial compression/decompression on CPUs|			
## Using command line interface (CLI)
* An executable ```MgardXExec``` will be built after building the MGARD-X library.
* To use the ```MgardXExec``` CLI, here are the options:

  + ```-z```: compress data
     + ```-i <path>``` path to data file to be compressed
     + ```-c <path>``` path to compressed file
     + ```-t <s|d>``` data type (s: single; d:double)
     + ```-n <D>``` total number of dimensions
       + ```<n_1>``` slowest dimention
       + ```<n_2>``` 2nd slowest dimention
       + ...
       + ```<n_D>``` fastest dimention
     + ```-u <path>``` path to coordinate file (non-uniform only)
     + ```-m <abs|rel>``` error bound mode (abs: abolute; rel: relative)
     + ```-e <error>``` error bound
     + ```-s <smoothness>``` smoothness parameter
     + ```-l <0|1|2>``` choose lossless compressor (0:Huffman 1:Huffman+LZ4 (NVIDIA GPU only) 2:Huffman@ZSTD)
  + ```-x```: decompress data
     + ```-c <path>``` path to compressed file
     + ```-d <path>``` path to decompressed file
  + ```-v``` enable verbose (show timing and statistics)
  + ```-d <auto|cuda|hip|serial>``` choose processor (auto: Auto select cuda: NVIDIA GPU, hip: AMD GPU serial: CPU)

	
## For using both the high-level APIs and low-level API
* **Include the header file.** MGARD-X APIs are included in both ```mgard/compress.hpp``` and ```mgard/compress_x.hpp```.
     + Use ```mgard/compress.hpp``` or ```mgard/compress_x.hpp``` if the user programs are to be compiled with ***non-CUDA*** compilers.
     + Use ```mgard/compress_x.hpp``` if the user programs are to be compiled with ***CUDA*** compilers.
* **Configure using ```mgard_x::Config```** Both high-level APIs and low-level APIs have an optional parameter for users to configure the compression/decomrpession process via ```mgard_x::Config``` class. To configure, create a ```mgard_x::Config``` object and configure its fields:
  + ```Config.dev_type```: sepcifying the processor for compression/decompression:
    + ```mgard_x::device_type::Auto```: Auto detect the best processor (***Default***)
    + ```mgard_x::device_type::CUDA```: Use NVIDIA GPUs
    + ```mgard_x::device_type::HIP ```: Use AMD GPUs
    + ```mgard_x::device_type::Serial```: Use CPUs
  + ```Config.dev_id```: sepcifying a specific GPU to use in multi-GPU systems (***Default: 0***)
  + ```Config.timing```: (true/false) timing each steps of compression and printing them out (***Default: false***).
  + ```Config.lossless```: control the lossless compression used: 
     + ```mgard_x::lossless_type::Huffman```: Huffman compression
     + ```mgard_x::lossless_type::Huffman_LZ4```: Huffman and LZ4 compression (***Default***)
     + ```mgard_x::lossless_type::Huffman_Zstd```: Huffman and ZSTD compression
     + *Note:* there will be no effect configuring the lossless comrpessor for decompression as MGARD has to use the same lossless compressor that was used for compression.
    
## Using high-level APIs
* **For compression:** ```void mgard_x::compress(mgard_x::DIM D, mgard_x::data_type dtype, std::vector<mgard_x::SIZE> shape, double tol, double s, enum error_bound_type mode, const void *original_data, void *&compressed_data, size_t &compressed_size, mgard_x::Config config)```
  + ```[In] shape:``` Shape of the Dataset to be compressed (from slowest to fastest).
  + ```[In] data_type:``` mgard_x::data_type::Float or mgard_x::data_type::Double.
  + ```[In] type:``` mgard_x::error_bound_type::REL or mgard_x::error_bound_type::ABS.
  + ```[In] tol:``` Error tolerance.
  + ```[In] s:``` Smoothness parameter.
  + ```[In] compressed_data:``` Dataset to be compressed.
  + ```[Out] compressed_size:``` Size of comrpessed data.
  + ```[In][Optional] coords:``` The coordinates in each dimension (from slowest to fastest).
  + ```[in][Optional] config:``` For configuring the compression process (optional).
  + ```[in] output_pre_allocated:``` Indicate whether or not the output buffer is pre-allocated. If not, MGARD will allocate the output buffer.

* **For decompression:** ```void decompress(const void *compressed_data, size_t compressed_size, void *&decompressed_data, Config config)```
  + ```[In] compressed_data:``` Compressed data.
  + ```[In] compressed_size:``` Size of comrpessed data.
  + ```[Out] decompressed_data:``` Decompressed data.
  + ```[In][Optional] config:``` For configuring the decompression process (optional).
  + ```[in] output_pre_allocated:``` Indicate whether or not the output buffer is pre-allocated. If not, MGARD will allocate the output buffer.

## Using low-level APIs
* **Step 1: Initialize mgard_x::Hierarchy.**
An object ```mgard_x::Hierarchy``` needs to be created and initialized. This initializes the necessary environment for efficient compression. It only needs to be created once if the input shape is not changed. For example, compressing the same variable on different timesteps only needs the Hierarchy object to be created once. Also, the same Hierarchy object can be reused in between compression and decompression APIs.
     + ```mgard_x:: Hierarchy<N_dims, D_type, Device_type>(std::vector<size_t> shape, std::vector<T*> coords, mgard_x::Config config)```.
        + ```[In] D_type```: Input data type (float or double)
        + ```[In] N_dims```: Total number of dimensions (<=5)
        + ```[In] Device_type ```: The type of device used (mgard\_x::CUDA, mgard\_x::HIP, or mgard\_x::Serial)
        + ```[In] shape```: Stores the size in each dimension (from slowest to fastest).
        + ```[In][Optional] coords```: The coordinates in each dimension (from slowest to fastest).
      	+ ```[In][Optional] config```: For configuring compression/decomrpession.
* **Step 2: Use mgard_x::Array.** ```mgard_x::Array``` is used for holding a managed array on GPU.
     +  For ***creating*** an array. ```mgard_x::Array::Array<N_dims, D_type, Device_type>(std::vector<size_t> shape)``` creates an manged array on GPU with ```shape```.
     +  For ***loading data*** into an array. ```void mgard_x::Array::load(D_type *data, size_t ld = 0)``` copies ```data``` into the the managed array on the targeting processor. ```data``` can be on either on CPU or GPU. An optional ```ld``` can be provided for specifying the size of the leading dimension.
     +  For ***accessing data from CPU*** ```D_type * mgard_x::Array::hostCopy()``` returns a CPU pointer of the array.
     +  For ***accessing data from GPU***```D_type * mgard_x::Array::data(size_t &ld)``` returns a pointer of the array on the targeting processor.
     +  For ***getting the shape*** of an array. ```std::vector<size_t> mgard_x::Array::shape()``` returns the shape of the managed array.

   ***Note:*** ```mgard_x::Array``` will automatically release its internal CPU/GPU array when it goes out of scope.
 
* **Step 3: Invoke compression/decompression.**:
  	+ For ***compression***: ```
			mgard_x::Array<1, unsigned char, Device_type> mgard_x::compress(mgard_x::Hierarchy <N_dims, D_type, Device_type> &hierarchy, mgard_x::Array<N_dims, D_type, Device_type> in_array, mgard_x::error_bound_type type, D_type tol, D_type s)```
     	- ```[In] in_array ```: Input data to be compressed (its value will be altered during compression).
     	- ```[In] type ```: Error bound type. ```mgard_x::error_bound_type::REL``` for relative error bound or ```mgard_x::error_bound_type::ABS``` for absolute error bound. 
	  	- ```[In] tol```: Error bound.
	  	- ```[In] s```: Smoothness parameter.
	  	- ```[Return]```: Compressed data.
  	+ For ***decompression***: ```mgard_x::Array<N_dims, D_type, Device_type> mgard_x::decompress(mgard_x::hierarchy <N_dims, D_type, Device_type> &hierarchy, mgard_x::Array<1, unsigned char, Device_type> compressed_data)```    
  		- ```[In] compressed_data ```: Compressed data.
  		- ```[Return]```: Decompressed data.
	

## A simple example
The following code shows how to compress/decompress a 3D dataset with the low-level APIs. 

		#include <vector>
		#include <iostream>
		#include "mgard/compress_x.hpp"
		int main() 
		{
		  mgard_x::SIZE n1 = 10;
		  mgard_x::SIZE n2 = 20;
		  mgard_x::SIZE n3 = 30;
		
		  //prepare 
		  std::cout << "Preparing data...";
		  double * in_array_cpu;
		  //... load data into in_array_cpu
		  std::vector<mgard_x::SIZE> shape{ n1, n2, n3 };
		  mgard_x::Hierarchy <3, double, mgard_x::CUDA> hierarchy(shape);
		  mgard_x::Array<3, double, mgard_x::CUDA> in_array(shape);
		  in_array.load(in_array_cpu);
		  std::cout << "Done\n";
		
		  std::cout << "Compressing with MGARD-X...";
		  double tol = 0.01, s = 0;
		  mgard_x::Array<1, unsigned char, mgard_x::CUDA> compressed_array = mgard_x::compress(hierarchy, in_array, mgard_x::error_bound_type::REL, tol, s);
		  mgard_x::SIZE compressed_size = compressed_array.shape()[0]; //compressed size in number of bytes.          
		  unsigned char * compressed_array_cpu = compressed_array.hostCopy();
		  std::cout << "Done\n";
		
		  std::cout << "Decompressing with MGARD-X...";
		  // decompression
		  mgard_x::Array<3, double, mgard_x::CUDA> decompressed_array = mgard_x::decompress(hierarchy, compressed_array);
		  double * decompressed_array_cpu = decompressed_array.hostCopy();
		  std::cout << "Done\n";
		}


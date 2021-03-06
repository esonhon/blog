#include <stdio.h>
#include <stdlib.h>

#include "common.h"

#include "cuda_runtime.h"
#include "device_launch_parameters.h"


#include "separable_convolution_gpu.h"

#define LOCAL					static 



LOCAL void HandleError(cudaError_t err,
	const char *file,
	int line) {
	if (err != cudaSuccess) {
		printf("%s in %s at line %d\n", cudaGetErrorString(err),
			file, line);
		exit(EXIT_FAILURE);
	}
}
#if(1)
#define getLastCudaError(msg) __getLastCudaError(msg, __FILE__, __LINE__)

inline void __getLastCudaError(const char *errorMessage, const char *file,
	const int line) {
	cudaError_t err = cudaGetLastError();

	if (cudaSuccess != err) {
		fprintf(stderr,
			"%s(%i) : getLastCudaError() CUDA error :"
			" %s : (%d) %s.\n",
			file, line, errorMessage, static_cast<int>(err),
			cudaGetErrorString(err));
		cudaDeviceReset();
		exit(EXIT_FAILURE);
	}
}
#endif

#define HANDLE_ERROR( err ) (HandleError( err, __FILE__, __LINE__ ))


LOCAL __global__ void SeparateConvolutionColumnGPULinearMemoryCU(
	int width, int height, float const *p_extended_input_dev,
	int kernel_length, float const *p_kernel_column_dev,
	float *p_column_done_extended_output_dev)
{
	int i, j;
	int kernel_radius;
	int extended_width;

	kernel_radius = kernel_length / 2;
	extended_width = width + 2 * kernel_radius;

	j = blockDim.y*blockIdx.y + threadIdx.y;
	for (; j < height; j += blockDim.y * gridDim.y) {
		

		i = blockDim.x*blockIdx.x + threadIdx.x;
		for (; i < width; i += blockDim.x * gridDim.x) {

			int jj;
			int x, y_mul_input_width;
			float sum;

			sum = 0;
			x = kernel_radius + i;
			y_mul_input_width = j*extended_width;
			
			for (jj = 0; jj < kernel_length; jj++) {

				sum += LDG(p_kernel_column_dev[jj])
					* LDG(p_extended_input_dev[y_mul_input_width + x]);

				y_mul_input_width += extended_width;
			}/*for kernel*/

			p_column_done_extended_output_dev[j*extended_width + x]
				= sum;
		}/*for i*/

	}/*for j*/

}/*SeparateConvolutionColumnGPULinearMemoryCU*/


LOCAL __global__ void SeparateConvolutionRowGPULinearMemoryCU(
	int width, int height, float const *p_row_done_extended_input_dev,
	int kernel_length, float const *p_kernel_column_dev,
	float *p_output_dev)
{

	int i, j;	
	int extended_width;
	int kernel_radius;

	kernel_radius = kernel_length / 2;
	extended_width = width + 2 * kernel_radius;


	j = blockDim.y*blockIdx.y + threadIdx.y;
	for (; j < height; j += blockDim.y * gridDim.y) {

		i = blockDim.x*blockIdx.x + threadIdx.x;
		for (; i < width; i += blockDim.x * gridDim.x) {

			int x, y_mul_input_width;
			int ii;
			float sum;

			sum = 0;
			y_mul_input_width = j*extended_width;
			x = i;

			for (ii = 0; ii < kernel_length; ii++) {

				sum += LDG(p_kernel_column_dev[ii])
					* LDG(p_row_done_extended_input_dev[y_mul_input_width + x]);
				x += 1;
			}/*for kernel_length*/

			p_output_dev[j*width + i] = sum;
		}/*for i*/

	}/*for j*/

}/*SeparateConvolutionRowGPULinearMemoryCU*/


int SeparableConvolutionColumnGPULinearMemory(
	dim3 num_blocks, dim3 num_threads,
	int width, int height, float const *p_extended_input_dev,
	int kernel_length, float const *p_kernel_column_dev,
	float *p_column_done_extended_output_dev)
{
	int extended_width;

	if (0 == width || 0 == height)
		return -1;

	if (kernel_length > width || kernel_length > height)
		return -2;

	extended_width = width + kernel_length - 1;

	
	HANDLE_ERROR(cudaMemset(p_column_done_extended_output_dev, 0,
		extended_width*height*sizeof(float)));

	SeparateConvolutionColumnGPULinearMemoryCU << <num_blocks, num_threads >> >
		(width, height, p_extended_input_dev, kernel_length,
			p_kernel_column_dev, p_column_done_extended_output_dev);

	getLastCudaError("SeparableConvolutionColumnGPULinearMemory");
	return 0;
}/*SeparableConvolutionColumnGPULinearMemory*/


int SeparableConvolutionRowGPULinearMemory(
	dim3 num_blocks, dim3 num_threads,
	int width, int height, float const *p_column_done_extended_input_dev,
	int kernel_length, float const *p_kernel_row_dev,
	float *p_output_dev)
{
	if (0 == width || 0 == height)
		return -1;

	if (kernel_length > width || kernel_length > height)
		return -2;

	SeparateConvolutionRowGPULinearMemoryCU << <num_blocks, num_threads >> >
		(width, height, p_column_done_extended_input_dev,
			kernel_length, p_kernel_row_dev, p_output_dev);

	getLastCudaError("SeparableConvolutionRowGPULinearMemory");
	return 0;
}/*SeparableConvolutionRowGPULinearMemory*/




LOCAL __constant__ float kernel_const_mem[1024];


LOCAL __global__ void SeparateConvolutionColumnGPUKernelInConstCU(
	int width, int height, float const *p_extended_input_dev,
	int kernel_length, float const *p_kernel_column_dev,
	float *p_column_done_extended_output_dev)
{
	int i, j;
	int kernel_radius;
	int extended_width;

	(void)p_kernel_column_dev;

	kernel_radius = kernel_length / 2;
	extended_width = width + 2 * kernel_radius;

	j = blockDim.y*blockIdx.y + threadIdx.y;
	for (; j < height; j += blockDim.y * gridDim.y) {

		i = blockDim.x*blockIdx.x + threadIdx.x;
		for (; i < width; i += blockDim.x * gridDim.x) {

			int jj;
			int x, y_mul_input_width;
			float sum;

			sum = 0;
			x = kernel_radius + i;
			y_mul_input_width = j*extended_width;

			for (jj = 0; jj < kernel_length; jj++) {

				sum += kernel_const_mem[jj]
					* LDG(p_extended_input_dev[y_mul_input_width + x]);

				y_mul_input_width += extended_width;
			}/*for kernel*/

			p_column_done_extended_output_dev[j*extended_width + x]
				= sum;
		}/*for i*/

	}/*for j*/

}/*SeparateConvolutionColumnGPUKernelInConstCU*/


LOCAL __global__ void SeparateConvolutionRowGPUKernelInConstCU(
	int width, int height, float const *p_column_done_extended_input_dev,
	int kernel_length, float const *p_kernel_row_dev,
	float *p_output_dev)
{

	int i, j;
	int extended_width;

	(void)p_kernel_row_dev;

	extended_width = width + kernel_length - 1;


	j = blockDim.y*blockIdx.y + threadIdx.y;
	for (; j < height; j += blockDim.y * gridDim.y) {

		i = blockDim.x*blockIdx.x + threadIdx.x;
		for (; i < width; i += blockDim.x * gridDim.x) {

			int x, y_mul_input_width;
			int ii;
			float sum;

			sum = 0;
			y_mul_input_width = j*extended_width;
			x = i;

			for (ii = 0; ii < kernel_length; ii++) {
				sum += kernel_const_mem[ii]
					* LDG(p_column_done_extended_input_dev[y_mul_input_width + x]);

				x += 1;
			}/*for kernel_length*/

			p_output_dev[j*width + i] = sum;
		}/*for i*/

	}/*for j*/

}/*SeparateConvolutionRowGPUKernelInConstCU*/


int SeparableConvolutionColumnGPUKernelInConst(
	dim3 num_blocks, dim3 num_threads,
	int width, int height, float const *p_extended_input_dev,
	int kernel_length, float const *p_kernel_column_host,
	float *p_column_done_extended_output_dev)
{
	int extended_width;
	float *p_kernel_const_dev;

	if (0 == width || 0 == height)
		return -1;

	if (kernel_length > width || kernel_length > height)
		return -2;

	extended_width = width + kernel_length - 1;

	HANDLE_ERROR(cudaGetSymbolAddress((void **)&p_kernel_const_dev,
		kernel_const_mem));

	HANDLE_ERROR(cudaMemcpy(p_kernel_const_dev, p_kernel_column_host,
		kernel_length * sizeof(float), cudaMemcpyHostToDevice));

	HANDLE_ERROR(cudaMemset(p_column_done_extended_output_dev, 0,
		extended_width*height * sizeof(float)));

	SeparateConvolutionColumnGPUKernelInConstCU << <num_blocks, num_threads >> >
		(width, height, p_extended_input_dev, kernel_length,
			NULL, p_column_done_extended_output_dev);

	getLastCudaError("SeparateConvolutionColumnGPUKernelInConstCU");
	return 0;
}/*SeparableConvolutionColumnGPUKernelInConst*/


int SeparableConvolutionRowGPUKernelInConst(
	dim3 num_blocks, dim3 num_threads,
	int width, int height, float const *p_column_done_extended_input_dev,
	int kernel_length, float const *p_kernel_row_host,
	float *p_output_dev)
{
	float *p_kernel_const_dev;

	if (0 == width || 0 == height)
		return -1;

	if (kernel_length > width || kernel_length > height)
		return -2;


	HANDLE_ERROR(cudaGetSymbolAddress((void **)&p_kernel_const_dev,
		kernel_const_mem));

	HANDLE_ERROR(cudaMemcpy(p_kernel_const_dev, p_kernel_row_host,
		kernel_length * sizeof(float), cudaMemcpyHostToDevice));

	SeparateConvolutionRowGPUKernelInConstCU << <num_blocks, num_threads >> >
		(width, height, p_column_done_extended_input_dev,
			kernel_length, NULL, p_output_dev);

	getLastCudaError("SeparateConvolutionRowGPUKernelInConstCU");
	return 0;
}/*SeparableConvolutionRowGPUKernelInConst*/



LOCAL __global__ void SeparateConvolutionColumnGPUKernelInConstSharedMemCU(
	int width, int height, float const *p_extended_input_dev,
	int kernel_length, float const *p_kernel_column_dev,
	float *p_column_done_extended_output_dev)
{
	int i, j;
	int kernel_radius;
	int extended_width;

	extern __shared__ float shared_mem[];
	float *p_input_in_block;
	int block_height;

	(void)p_kernel_column_dev;

	kernel_radius = kernel_length / 2;
	extended_width = width + 2 * kernel_radius;

	p_input_in_block = &shared_mem[0];

	block_height = blockDim.y + (kernel_length - 1);

#ifdef _COLUMN_DATA_IN_CONSECUTIVE_SHARED_MEN

	j = blockDim.y*blockIdx.y + threadIdx.y;
	for (; j < height; j += blockDim.y * gridDim.y) {

		i = blockDim.x*blockIdx.x + threadIdx.x;
		for (; i < width; i += blockDim.x * gridDim.x) {

			int jj;
			int x;
			float sum;

			sum = 0;
			x = kernel_radius + i;
			jj = 0;

			do {
				p_input_in_block[threadIdx.x * block_height
					+ jj*blockDim.y + threadIdx.y]
					= p_extended_input_dev
					[(j + jj*blockDim.y)*extended_width
					+ kernel_radius + i];

				jj++;
			} while (threadIdx.y + jj * blockDim.y < block_height);

			__syncthreads();

			for (jj = 0; jj < kernel_length; jj++) {
				sum += kernel_const_mem[jj] * p_input_in_block[
					threadIdx.x*block_height + jj + threadIdx.y];
			}/*for kernel*/

			p_column_done_extended_output_dev[j*extended_width + kernel_radius + i]
				= sum;

			__syncthreads();
		}/*for i*/

	}/*for j*/

#else

	j = blockDim.y*blockIdx.y + threadIdx.y;
	for (; j < height; j += blockDim.y * gridDim.y) {

		i = blockDim.x*blockIdx.x + threadIdx.x;
		for (; i < width; i += blockDim.x * gridDim.x) {

			int jj;
			float sum;

			sum = 0;

			jj = 0;
			do {
				p_input_in_block[(threadIdx.y + jj*blockDim.y)*blockDim.x
					+ threadIdx.x] 
					= p_extended_input_dev
					[ (j + jj*blockDim.y)*extended_width
					+ kernel_radius + i];
				jj++;
			} while (threadIdx.y + jj * blockDim.y <  block_height);
		
			__syncthreads();


			for (jj = 0; jj < kernel_length; jj++) {
				sum += kernel_const_mem[jj]* p_input_in_block[
					(threadIdx.y + jj)*blockDim.x + threadIdx.x];
			}/*for kernel*/

			p_column_done_extended_output_dev[j*extended_width + kernel_radius + i]
				= sum;

			__syncthreads();
		}/*for i*/
		
	}/*for j*/

#endif

}/*SeparateConvolutionColumnGPUKernelInConstSharedMemCU*/


LOCAL __global__ void SeparateConvolutionRowGPUKernelInConstSharedMemCU(
	int width, int height, float const *p_column_done_extended_input_dev,
	int kernel_length, float const *p_kernel_row_dev,
	float *p_output_dev)
{
	int i, j;
	int extended_width;

	extern __shared__ float shared_mem[];
	float *p_input_in_block;
	int block_width;

	(void)p_kernel_row_dev;

	
	extended_width = width + kernel_length - 1;

	p_input_in_block = &shared_mem[0];
	block_width = blockDim.x + (kernel_length - 1);


	j = blockDim.y*blockIdx.y + threadIdx.y;
	for (; j < height; j += blockDim.y * gridDim.y) {

		i = blockDim.x*blockIdx.x + threadIdx.x;
		for (; i < width; i += blockDim.x * gridDim.x) {
			int ii;
			float sum;

			sum = 0;
			ii = 0;

			do {
				p_input_in_block[threadIdx.y*block_width
					+ ii*blockDim.x + threadIdx.x] =
					p_column_done_extended_input_dev[j*extended_width
					+ ii*blockDim.x + i];

				ii++;
			} while (threadIdx.x + ii* blockDim.x < block_width);

			__syncthreads();


			for (ii = 0; ii < kernel_length; ii++) {
				sum += kernel_const_mem[ii]* p_input_in_block[
					threadIdx.y*block_width + ii + threadIdx.x];
			}/*for kernel_length*/
			
			p_output_dev[j*width + i] = sum;
			__syncthreads();
		}/*for i*/

	}/*for j*/

}/*SeparateConvolutionRowGPUKernelInConstSharedMemCU*/


int SeparableConvolutionColumnGPUKernelInConstSharedMem(
	dim3 num_blocks, dim3 num_threads,
	int width, int height, float const *p_extended_input_dev,
	int kernel_length, float const *p_kernel_column_host,
	float *p_column_done_extended_output_dev)
{
	int extended_width;
	float *p_kernel_const_dev;
	int kernel_radius;
	int shared_mem_size;
	int block_height;

	if (0 == width || 0 == height)
		return -1;

	if (kernel_length > width || kernel_length > height)
		return -2;

	kernel_radius = kernel_length / 2;

	extended_width = width + 2* kernel_radius;
	block_height = num_threads.y + (kernel_length - 1);

	shared_mem_size = sizeof(float)*
		(block_height)*(num_threads.x);

	HANDLE_ERROR(cudaGetSymbolAddress((void **)&p_kernel_const_dev,
		kernel_const_mem));

	HANDLE_ERROR(cudaMemcpy(p_kernel_const_dev, p_kernel_column_host,
		kernel_length * sizeof(float), cudaMemcpyHostToDevice));

	HANDLE_ERROR(cudaMemset(p_column_done_extended_output_dev, 0,
		extended_width*height * sizeof(float)));

	SeparateConvolutionColumnGPUKernelInConstSharedMemCU 
		<< <num_blocks, num_threads, shared_mem_size >> >
		(width, height, p_extended_input_dev, kernel_length,
			NULL, p_column_done_extended_output_dev);
	
	getLastCudaError("SeparateConvolutionColumnGPUKernelInConstSharedMemCU");
	return 0;
}/*SeparableConvolutionColumnGPUKernelInConstSharedMem*/


int SeparableConvolutionRowGPUKernelInConstSharedMem(
	dim3 num_blocks, dim3 num_threads,
	int width, int height, float const *p_column_done_extended_input_dev,
	int kernel_length, float const *p_kernel_row_host,
	float *p_output_dev)
{
	float *p_kernel_const_dev;
	int shared_mem_size;
	int block_width;

	if (0 == width || 0 == height)
		return -1;

	if (kernel_length > width || kernel_length > height)
		return -2;

	block_width = num_threads.x + (kernel_length - 1);
	shared_mem_size = sizeof(float)*
		(block_width)*(num_threads.y);

	HANDLE_ERROR(cudaGetSymbolAddress((void **)&p_kernel_const_dev,
		kernel_const_mem));

	HANDLE_ERROR(cudaMemcpy(p_kernel_const_dev, p_kernel_row_host,
		kernel_length * sizeof(float), cudaMemcpyHostToDevice));

	SeparateConvolutionRowGPUKernelInConstSharedMemCU 
		<< <num_blocks, num_threads, shared_mem_size >> >
		(width, height, p_column_done_extended_input_dev,
			kernel_length, NULL, p_output_dev);

	getLastCudaError("SeparateConvolutionRowGPUKernelInConstSharedMemCU");

	return 0;
}/*SeparableConvolutionRowGPUKernelInConstSharedMem*/


LOCAL __global__ void SeparateConvolutionColumnGPUKernelInConstSharedMemPaddingCU(
	int width, int height, float const *p_extended_input_dev,
	int kernel_length, float const *p_kernel_column_dev,
	float *p_column_done_extended_output_dev, const int padding)
{
	int i, j;
	int kernel_radius;
	int extended_width;

	extern __shared__ float shared_mem[];
	float *p_input_in_block;
	int block_height;
	int shared_mem_pitch;

	(void)p_kernel_column_dev;

	kernel_radius = kernel_length / 2;
	extended_width = width + 2 * kernel_radius;

	p_input_in_block = &shared_mem[0];

	block_height = blockDim.y + (kernel_length - 1);
	
#ifdef _COLUMN_DATA_IN_CONSECUTIVE_SHARED_MEN

	shared_mem_pitch = block_height;
	shared_mem_pitch += padding;

	j = blockDim.y*blockIdx.y + threadIdx.y;
	for (; j < height; j += blockDim.y * gridDim.y) {

		i = blockDim.x*blockIdx.x + threadIdx.x;
		for (; i < width; i += blockDim.x * gridDim.x) {

			int jj;
			int x;
			float sum;

			sum = 0;
			x = kernel_radius + i;
			jj = 0;

			do {
				p_input_in_block[threadIdx.x * shared_mem_pitch
					+ jj*blockDim.y + threadIdx.y]
					= p_extended_input_dev
					[(j + jj*blockDim.y)*extended_width
					+ kernel_radius + i];

				jj++;
			} while (threadIdx.y + jj * blockDim.y < block_height);

			__syncthreads();

			for (jj = 0; jj < kernel_length; jj++) {
				sum += kernel_const_mem[jj] * p_input_in_block[
					threadIdx.x*shared_mem_pitch + jj + threadIdx.y];
			}/*for kernel*/

			p_column_done_extended_output_dev[j*extended_width 
				+ kernel_radius + i]
				= sum;

			__syncthreads();
		}/*for i*/

	}/*for j*/

#else

	shared_mem_pitch = blockDim.x;
	shared_mem_pitch += padding;

	j = blockDim.y*blockIdx.y + threadIdx.y;
	for (; j < height; j += blockDim.y * gridDim.y) {

		i = blockDim.x*blockIdx.x + threadIdx.x;
		for (; i < width; i += blockDim.x * gridDim.x) {

			int jj;
			float sum;

			sum = 0;

			jj = 0;
			do {
				p_input_in_block[(threadIdx.y + jj*blockDim.y)* shared_mem_pitch
					+ threadIdx.x]
					= p_extended_input_dev
					[(j + jj*blockDim.y)*extended_width
					+ kernel_radius + i];

				jj++;
			} while (threadIdx.y + jj * blockDim.y < block_height);

			__syncthreads();


			for (jj = 0; jj < kernel_length; jj++) {
				sum += kernel_const_mem[jj] * p_input_in_block[
					(threadIdx.y + jj)*shared_mem_pitch + threadIdx.x];
			}/*for kernel*/

			p_column_done_extended_output_dev[j*extended_width 
				+ kernel_radius + i] = sum;

			__syncthreads();
		}/*for i*/

	}/*for j*/

#endif

}/*SeparateConvolutionColumnGPUKernelInConstSharedMemPaddingCU*/


LOCAL __global__ void SeparateConvolutionRowGPUKernelInConstSharedMemPaddingCU(
	int width, int height, float const *p_column_done_extended_input_dev,
	int kernel_length, float const *p_kernel_row_dev,
	float *p_output_dev, const int padding)
{
	int i, j;
	int kernel_radius;
	int extended_width;

	extern __shared__ float shared_mem[];
	float *p_input_in_block;
	int block_width;
	int shared_mem_pitch;

	(void)p_kernel_row_dev;

	kernel_radius = kernel_length / 2;
	extended_width = width + 2 * kernel_radius;

	p_input_in_block = &shared_mem[0];
	block_width = blockDim.x + (kernel_length - 1);

	shared_mem_pitch = block_width;
	shared_mem_pitch += padding;

	j = blockDim.y*blockIdx.y + threadIdx.y;
	for (; j < height; j += blockDim.y * gridDim.y) {

		i = blockDim.x*blockIdx.x + threadIdx.x;
		for (; i < width; i += blockDim.x * gridDim.x) {
			int ii;
			float sum;

			sum = 0;
			ii = 0;

			do {
				p_input_in_block[threadIdx.y*shared_mem_pitch
					+ ii*blockDim.x + threadIdx.x] =
					p_column_done_extended_input_dev[j*extended_width
					+ ii*blockDim.x + i];

				ii++;
			} while (threadIdx.x + ii * blockDim.x < block_width);

			__syncthreads();


			for (ii = 0; ii < kernel_length; ii++) {
				sum += kernel_const_mem[ii] * p_input_in_block[
					threadIdx.y*shared_mem_pitch + ii + threadIdx.x];
			}/*for kernel_length*/

			p_output_dev[j*width + i] = sum;
			__syncthreads();
		}/*for i*/

	}/*for j*/

}/*SeparateConvolutionRowGPUKernelInConstSharedMemPaddingCU*/

#define WARP_SIZE					(32)

int SeparableConvolutionColumnGPUKernelInConstSharedMemPadding(
	dim3 num_blocks, dim3 num_threads,
	int width, int height, float const *p_extended_input_dev,
	int kernel_length, float const *p_kernel_column_host,
	float *p_column_done_extended_output_dev)
{
	int extended_width;
	float *p_kernel_const_dev;
	int shared_mem_size;
	int kernel_radius;
	
	int block_height;
	int padding;


	if (0 == width || 0 == height)
		return -1;

	if (kernel_length > width || kernel_length > height)
		return -2;

	kernel_radius = kernel_length / 2;
	extended_width = width + 2 * kernel_radius;

	block_height = num_threads.y + (kernel_length - 1);

/*
	padding
	= WARP_SIZE*n - (block_size + num_threads + (WARP_SIZE - num_threads))
*/
#ifdef _COLUMN_DATA_IN_CONSECUTIVE_SHARED_MEN
	/*unable to completely solve the bank conflict, 
	only mitigate it*/

	{
		int temp = block_height + (WARP_SIZE - num_threads.y);

		padding = WARP_SIZE*((temp + (WARP_SIZE - 1)) / WARP_SIZE)
			- temp;
	}/*local variable*/

	padding += 1;	

	shared_mem_size = sizeof(float)
		*(block_height + padding)*(num_threads.x);
	
#else
/*
	padding
	= WARP_SIZE*n - (block_size + (WARP_SIZE - num_threads))
	-> padding = num_threads.x + (WARP_SIZE - num_threads.x);
*/
	padding = 0;
	shared_mem_size = sizeof(float)
		* (num_threads.x + padding) *(block_height);
#endif

	HANDLE_ERROR(cudaGetSymbolAddress((void **)&p_kernel_const_dev,
		kernel_const_mem));

	HANDLE_ERROR(cudaMemcpy(p_kernel_const_dev, p_kernel_column_host,
		kernel_length * sizeof(float), cudaMemcpyHostToDevice));

	HANDLE_ERROR(cudaMemset(p_column_done_extended_output_dev, 0,
		extended_width*height * sizeof(float)));

	SeparateConvolutionColumnGPUKernelInConstSharedMemPaddingCU
		<< <num_blocks, num_threads, shared_mem_size >> >
		(width, height, p_extended_input_dev, kernel_length,
			NULL, p_column_done_extended_output_dev, padding);

	getLastCudaError("SeparateConvolutionColumnGPUKernelInConstSharedMemPaddingCU");
	return 0;
}/*SeparableConvolutionColumnGPUKernelInConstSharedMemPadding*/


int SeparableConvolutionRowGPUKernelInConstSharedMemPadding(
	dim3 num_blocks, dim3 num_threads,
	int width, int height, float const *p_column_done_extended_input_dev,
	int kernel_length, float const *p_kernel_row_host,
	float *p_output_dev)
{
	float *p_kernel_const_dev;
	int shared_mem_size;

	int block_width;	
	int padding;

	if (0 == width || 0 == height)
		return -1;

	if (kernel_length > width || kernel_length > height)
		return -2;

	block_width = num_threads.x + (kernel_length - 1);
/*
	padding 
	= WARP_SIZE*n - (block_size + (WARP_SIZE - num_threads))
*/
	{
		int temp = block_width + (WARP_SIZE - num_threads.x);

		padding = WARP_SIZE*((temp + (WARP_SIZE - 1)) / WARP_SIZE)
			- temp;
	}/*local variable*/

	shared_mem_size = sizeof(float) 
		* (block_width + padding) *(num_threads.y);

	HANDLE_ERROR(cudaGetSymbolAddress((void **)&p_kernel_const_dev,
		kernel_const_mem));

	HANDLE_ERROR(cudaMemcpy(p_kernel_const_dev, p_kernel_row_host,
		kernel_length * sizeof(float), cudaMemcpyHostToDevice));

	SeparateConvolutionRowGPUKernelInConstSharedMemPaddingCU
		<< <num_blocks, num_threads, shared_mem_size >> >
		(width, height, p_column_done_extended_input_dev,
			kernel_length, NULL, p_output_dev, padding);

	getLastCudaError("SeparateConvolutionRowGPUKernelInConstSharedMemPaddingCU");

	return 0;
}/*SeparableConvolutionColumnGPUKernelInConstSharedMemPadding*/

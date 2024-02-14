#include "linear.h"
#include <cuda_runtime.h>
#include <curand_kernel.h>
#include <random>
#include<iostream>
#include "../utils/Errorhelper.cpp"
namespace Hex{

	template<class T>
	__global__ void initWeightKernel(T* weights, T* bias, int output_size, int input_size, bool bias_as_zero, float w_b_range ) {
		int i = blockIdx.x * blockDim.x + threadIdx.x;
		int j = blockIdx.y * blockDim.y + threadIdx.y;

		if (i < output_size && j < input_size) {
			//// Random initialization of weights within the specified range
			curandState state;
			curand_init(clock64(), i * input_size + j, 0, &state);

			float float_weight = (2 * curand_uniform(&state) - 1) * w_b_range;
			weights[i * input_size + j] = static_cast<T>(float_weight);
		}

		//// Initialize bias if Isbias is true
		if (  i < output_size && j == 0) {
			if (bias_as_zero) {
				 
				bias[i] = static_cast<T>(0.0);
			}
			else {
				curandState state_bias;
				curand_init(clock64(), i, 0, &state_bias);

				float float_bias = (2 * curand_uniform(&state_bias) - 1) * w_b_range;
				bias[i] = static_cast<T>(float_bias);
			}
			
		}

		/*int i = blockIdx.x * blockDim.x + threadIdx.x;
		int j = blockIdx.y * blockDim.y + threadIdx.y;

		if (i < output_size && j < input_size) {
			 
			weights[i * input_size + j] = static_cast<T>(i * input_size + j + 1);   
		}

		 Initialize bias if Isbias is true
		if (  i < output_size && j == 0) {
			if (bias_as_zero) {
				bias[i] = static_cast<T>(0.0);
			}
			else {
				 
				bias[i] = static_cast<T>(i + 1);   
			}
		}*/
	}

	template<class T>
	__global__ void linearLayerForward(const T* W, const T* X, T* Y, const T* b,
		int W_x_dim, int W_y_dim,
		int X_x_dim, int X_y_dim) {

		int col = blockIdx.y * blockDim.y + threadIdx.y;
		int row = blockIdx.x * blockDim.x + threadIdx.x;
	

		int Y_x_dim = W_x_dim;
		int Y_y_dim = X_y_dim;

		T Y_value = 0;

		if (row < Y_x_dim && col < Y_y_dim) {
			// Perform the matrix multiplication: Y = W * A  
			for (int i = 0; i < W_y_dim; ++i) {
				Y_value += W[row * W_y_dim + i] * X[i]; 
				//printf("W[row * W_y_dim + i] %d\n", W[row * W_y_dim + i]);
				 //	printf("W[row * W_x_dim + i] %d\n", W[i * W_x_dim + row]);
				//Y_value += W[row * W_y_dim + i] * X[i * X_y_dim + col]; 
			}
	
			// Add bias Y_value + b
			Y_value += b[row];
			
			// Store the result in the output tensor
			Y[row * Y_y_dim + col] = Y_value;
		}
 

	}


	template<class T>
	linear<T>::linear(int input_size, int output_size,bool bias_as_zero, float w_b_range )
		: _bias_as_zero(bias_as_zero), _w_b_range(w_b_range) ,
		weights(std::vector<int>{output_size , input_size  }),
		bias(   std::vector<int>{output_size,1}) , 
		output(std::vector<int>{output_size, 1  }),
		input(std::vector<int>{input_size, 1  }),
		input_error(std::vector<int>{input_size, 1  })
	{ 
		init_weight_n_bias();
	}

	template<class T>
	linear<T>::~linear()
	{
		output.cudafree();
		input.cudafree();
		input_error.cudafree();
	}


	template<class T>
	Tensor<T>& linear<T>::forward(Tensor<T>& input_tensor)
	{
		input = input_tensor;
		if (weights.getShape()[1] != input.getShape()[0]) {
			std::cerr << "Error: Tensor shapes must be the same for addition. Shape of tensor1: "
				<< weights.getShape()[1] << ", Shape of tensor2: " << input.getShape()[0] << std::endl;
			throw std::runtime_error("Tensor shape mismatch");
		}
		//std::cout << "dbug strat of linear" << std::endl;
		//std::cout << "weight" << std::endl;
		//weights.print();

		//std::cout << "intpu" << std::endl;
		//input.print();
		//std::cout << "bias" << std::endl;
		//bias.print();

		dim3 threadsPerBlock(256);
		dim3 numBlocks((output.getShape()[0] + threadsPerBlock.x - 1) / threadsPerBlock.x,
			(output.getShape()[1] + threadsPerBlock.y - 1) / threadsPerBlock.y);
		// Launch the forward kernel
		 
		linearLayerForward << <numBlocks, threadsPerBlock >> > (weights.getData(), input.getData(), output.getData(), bias.getData(),
			weights.getShape()[0], weights.getShape()[1] ,
			input.getShape()[0], input.getShape()[1]);
		cudaDeviceSynchronize();
/*	 	std::cout << "output" << std::endl;
		output.print();*/ 
		 
		cudaError_t cudaError = cudaGetLastError();
		if (cudaError == cudaErrorInvalidValue) {
			printf("error from liner forward method: %s\n", cudaGetErrorString(cudaError));
			  exit(EXIT_FAILURE);  // or handle the error appropriately
		}
	
		//std::cout << "dbug end of linear" << std::endl;
		//std::cout << std::endl;
		//std::cout << std::endl;
		//std::cout << std::endl;
		return output;
	}

	template<class T>
	__global__ void backpropagationAndUpdateKernel(T* weights, T* bias,
		const T* output_error,const T* input_data, T* input_error,
		float learning_rate, int w_x_dim, int w_y_dim,
		int input_x_dim, int input_y_dim)
	{
		int row = blockIdx.x * blockDim.x + threadIdx.x;
		int col = blockIdx.y * blockDim.y + threadIdx.y;
		
		if (row < w_y_dim && col < input_y_dim) {
			T sum = 0;
			for (int i = 0; i < w_x_dim; ++i) {
				sum  += weights[i * w_y_dim + row] * output_error[i]; 
			} 
			input_error[row * input_y_dim + col] = sum; 
			
		}

		if (row < w_x_dim && col < input_y_dim) {
			T gw = 0;
			
			bias[row] -= learning_rate * output_error[row];
			for (int i = 0; i < w_y_dim; ++i) {
				 gw  = output_error[row] * input_data[i]; 
				 weights[row * w_y_dim + i] = weights[row * w_y_dim + i] - learning_rate * gw;
				// printf("weight from kernalaaaaaaaaaaaaa %f \n", weights[row * w_y_dim + i]);
			}
			
		}
	}

	template<class T>
	Tensor<T>& linear<T>::backpropagation(Tensor<T>& output_error, float learning_rate)
	{
		
		dim3 threadsPerBlock(16, 16);
		dim3 numBlocks((weights.getShape()[1] + threadsPerBlock.x - 1) / threadsPerBlock.x,
			(weights.getShape()[0] + threadsPerBlock.y - 1) / threadsPerBlock.y);
		 
		backpropagationAndUpdateKernel << <numBlocks, threadsPerBlock >> > (
			weights.getData(), bias.getData(),
			output_error.getData(), input.getData(), input_error.getData(),
			learning_rate, weights.getShape()[0], weights.getShape()[1],
			output_error.getShape()[0], output_error.getShape()[1]);
		cudaDeviceSynchronize();
		cudaError_t cudaError = cudaGetLastError();
		if (cudaError != cudaSuccess) {
			printf("error from liner backword method : %s\n", cudaGetErrorString(cudaError));
			exit(EXIT_FAILURE);  // or handle the error appropriately
		}
		return input_error;


	}



	template<class T>
	void linear<T>::init_weight_n_bias() {
		dim3 threadsPerBlock(16, 16);
		dim3 numBlocks((weights.getShape()[1] + threadsPerBlock.x - 1) / threadsPerBlock.x,
			(weights.getShape()[0] + threadsPerBlock.y - 1) / threadsPerBlock.y);

		// Launch the kernel to initialize weights and bias
		initWeightKernel << <numBlocks, threadsPerBlock >> > (weights.getData(), bias.getData(), weights.getShape()[0],
															 weights.getShape()[1], _bias_as_zero, _w_b_range );
		cudaDeviceSynchronize();   
	}

 

	template<class T>
	Tensor<T>& linear<T>::printW()
	{
		return weights;
	}

	template<class T>
	Tensor<T>& linear<T>::printB()
	{
		return bias;
	}
 
    // Explicit instantiation of the template class for supported types
    template class linear<float>;
    template class linear<int>;
    template class linear<double>;
}
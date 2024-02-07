﻿#include <iostream>

#include <stdexcept>
 
#include"Tensor.h"
#include "tensor_oprations.cuh"
#include "linear.h"
#include "ReLU.h"
using namespace Hex;
using namespace std;

template <class T>
void printtensor(const Tensor<T>& tensor1) {
    tensor1.print();
}


int main() {
     
    // memory get overloaded on {330, 3, 2048, 1080 }
    //std::unique_ptr<Tensor<int>> tensorA(new Tensor<int>({330, 3, 2048, 1080 }));
    //std::unique_ptr<Tensor<int>> tensorB(new Tensor<int>({ 330,3, 2048, 1080 }));
    std::unique_ptr<Tensor<float>> tensorA(new Tensor<float>({3,1 }));
    std::unique_ptr<Tensor<int>> tensorB(new Tensor<int>({ 3,1 }));
    linear<float> linearLayer(3,2   ,false   );
    ReLU<float> relu;
    
    // Initialize tensors on GPU
    initTensorOnGPU(*tensorA , 0.0);
    initTensorOnGPU(*tensorB , 0.0);
    std::cout << "tensor init done" << std::endl;
    // Perform element-wise addition for 3D tensors
    auto tensorC = Hex::addTensor(*tensorA, *tensorB);

  
    // Print the result tensor
     std::cout << "\ninput:" << std::endl;
     printtensor(*tensorB);

     std::cout << "\nweight" << std::endl;
     printtensor(linearLayer.printW());

     std::cout << "\nbias" << std::endl;
     printtensor(linearLayer.printB());

     // Print the result tensor
     std::cout << "\nAFTER liner calculation: " << std::endl;
     auto a = linearLayer.forward(*tensorA );
     printtensor(a);
 


     std::cout << "\nRELU" << std::endl;
     auto active = relu.forward(a);
     printtensor(active);




     // back propa

     std::cout << "\nRELU backpropagation" << std::endl;
     auto active2 = relu.backpropagation(active);
     printtensor(active2);

     std::cout << "\nafter backward calculation:" << std::endl;
     auto b = linearLayer.backpropagation(active2);
     printtensor(b);


     std::cout << "\nweight" << std::endl;
     printtensor(linearLayer.printW());

     std::cout << "\nbias" << std::endl;
     printtensor(linearLayer.printB());


    return 0;
}

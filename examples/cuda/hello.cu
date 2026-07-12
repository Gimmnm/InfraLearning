#include <iostream>
#include <cuda_runtime.h>

// CUDA 核函数
__global__ void vectorAdd(const float* A, const float* B, float* C, int n) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < n) {
        C[idx] = A[idx] + B[idx];
    }
}

// 错误检查宏
#define CUDA_CHECK(call) \
    do { \
        cudaError_t err = call; \
        if (err != cudaSuccess) { \
            std::cerr << "CUDA 错误：" << cudaGetErrorString(err) \
                      << " 在 " << __FILE__ << ":" << __LINE__ << std::endl; \
            exit(1); \
        } \
    } while(0)

int main() {
    // 1. 检查设备
    int deviceCount;
    CUDA_CHECK(cudaGetDeviceCount(&deviceCount));
    if (deviceCount == 0) {
        std::cerr << "没有找到支持 CUDA 的设备！" << std::endl;
        return 1;
    }
    std::cout << "找到 " << deviceCount << " 个 CUDA 设备" << std::endl;

    // 2. 数据大小
    int n = 1 << 20;
    size_t size = n * sizeof(float);

    // 3. 主机内存分配与初始化
    float* h_A = new float[n];
    float* h_B = new float[n];
    float* h_C = new float[n];

    for (int i = 0; i < n; ++i) {
        h_A[i] = static_cast<float>(i);
        h_B[i] = static_cast<float>(i * 2.0f);
    }

    // 4. 设备内存分配
    float *d_A, *d_B, *d_C;
    CUDA_CHECK(cudaMalloc(&d_A, size));
    CUDA_CHECK(cudaMalloc(&d_B, size));
    CUDA_CHECK(cudaMalloc(&d_C, size));

    // 5. 拷贝数据到设备
    CUDA_CHECK(cudaMemcpy(d_A, h_A, size, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_B, h_B, size, cudaMemcpyHostToDevice));

    // 6. 配置核函数
    int threadsPerBlock = 256;
    int blocksPerGrid = (n + threadsPerBlock - 1) / threadsPerBlock;

    // 7. 启动核函数
    vectorAdd<<<blocksPerGrid, threadsPerBlock>>>(d_A, d_B, d_C, n);

    // 检查核函数启动错误
    CUDA_CHECK(cudaGetLastError());

    // 等待核函数完成
    CUDA_CHECK(cudaDeviceSynchronize());

    // 8. 拷贝结果回主机
    CUDA_CHECK(cudaMemcpy(h_C, d_C, size, cudaMemcpyDeviceToHost));

    // 9. 输出前10个结果验证
    std::cout << "计算结果示例（前10个元素）：" << std::endl;
    for (int i = 0; i < 10 && i < n; ++i) {
        std::cout << "C[" << i << "] = " << h_C[i]
                  << " (期望 " << h_A[i] + h_B[i] << ")" << std::endl;
    }

    // 10. 释放内存
    CUDA_CHECK(cudaFree(d_A));
    CUDA_CHECK(cudaFree(d_B));
    CUDA_CHECK(cudaFree(d_C));
    delete[] h_A;
    delete[] h_B;
    delete[] h_C;

    return 0;
}
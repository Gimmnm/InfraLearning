cmake_minimum_required(VERSION 3.18)
project(cuda_hello LANGUAGES CXX CUDA)
set(CMAKE_CUDA_ARCHITECTURES 89)  # RTX 4090 = sm_89
add_executable(hello hello.cu)

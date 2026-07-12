import torch

print(f"torch={torch.__version__}")
print(f"cuda_available={torch.cuda.is_available()}")
assert torch.cuda.is_available(), "CUDA not available"
print(f"device={torch.cuda.get_device_name(0)}")
print(f"capability={torch.cuda.get_device_capability(0)}")

a = torch.randn(2048, 2048, device="cuda")
b = a @ a.T
print(f"matmul OK, mean={b.mean().item():.6f}")
print("PyTorch hello OK")

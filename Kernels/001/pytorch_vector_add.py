import torch

N = 1 << 26 # 约 67M元素
a = torch.randn(N, device = 'cuda', dtype = torch.float32)
b = torch.randn(N, device = 'cuda', dtype = torch.float32)

_ = a + b

def benchmark_add(func, *argc, name = 'Add', n_warmup = 5, n_repeat = 20):
    
	start = torch.cuda.Event(enable_timing = True)
	end = torch.cuda.Event(enable_timing = True)

	start.record()
	for _ in range(n_repeat):
		func(*argc)
	end.record()
	torch.cuda.synchronize()

	elapsed_ms = start.elapsed_time(end) / n_repeat
	return elapsed_ms

ms = benchmark_add(lambda x, y : x + y, a, b, name = "PyTorch add")

# 计算有效带宽
# 读取(a, b, 写入 c，共3 * N * sizeof(float)) 字节
bytes_total = 3 * N * 4
bw = (bytes_total / 1e9) / (ms / 1000.0)

print(f"Pytorch add: {ms:.3f}ms, {bw:.2f}GB/s")
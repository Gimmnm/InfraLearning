"""Minimal Triton sanity check."""
import torch
import triton
import triton.language as tl


@triton.jit
def add_kernel(x_ptr, y_ptr, out_ptr, n, BLOCK: tl.constexpr):
    pid = tl.program_id(0)
    offs = pid * BLOCK + tl.arange(0, BLOCK)
    mask = offs < n
    x = tl.load(x_ptr + offs, mask=mask)
    y = tl.load(y_ptr + offs, mask=mask)
    tl.store(out_ptr + offs, x + y, mask=mask)


def main():
    print(f"torch={torch.__version__}")
    print(f"cuda={torch.cuda.is_available()} {torch.version.cuda}")
    print(f"triton={triton.__version__}")
    assert torch.cuda.is_available(), "CUDA not available"

    n = 4096
    x = torch.randn(n, device="cuda")
    y = torch.randn(n, device="cuda")
    out = torch.empty_like(x)
    add_kernel[(triton.cdiv(n, 128),)](x, y, out, n, BLOCK=128)
    torch.cuda.synchronize()

    max_err = (out - (x + y)).abs().max().item()
    print(f"triton kernel OK, max_err={max_err:.2e}")
    assert max_err < 1e-5


if __name__ == "__main__":
    main()

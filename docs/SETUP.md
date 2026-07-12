# 环境配置指南（新机器快速复现）

面向 AutoDL / 同类 GPU 云主机：Ubuntu 22.04、已装 NVIDIA 驱动与 CUDA Toolkit、系统盘较小、数据盘在 `/root/autodl-tmp`。

本机已验证组合（2026-07）：

| 组件 | 版本 |
|------|------|
| GPU / Driver | RTX 4090 / 560.x（驱动 CUDA 上限 12.6） |
| CUDA Toolkit | **12.4**（`nvcc`） |
| Python | **3.10**（系统 `/usr/bin/python3.10`） |
| 包管理 | **uv**（不用 conda） |
| PyTorch | **2.6.0+cu124** |
| Triton | **3.2.0**（随 torch cu124 轮子） |

> 驱动最高支持 CUDA 12.6 时，务必装 **cu124**（或 cu121/cu126）的 torch，不要装到 cu130，否则 `torch.cuda.is_available()` 会为 False。

---

## 一键配置（推荐）

在项目根目录执行：

```bash
bash scripts/setup_env.sh
```

脚本会：

1. 检查 `nvidia-smi` / `nvcc`
2. 安装 C++ / Triton 编译依赖（gcc、cmake、ninja、gdb、ccache、eigen、`python3-dev`）
3. 安装 `uv` 到 `~/.local/bin`
4. 在数据盘创建 venv：`/root/autodl-tmp/venvs/cuda-learn`，并链到项目 `.venv`
5. 安装 PyTorch / torchvision / Triton（cu124 源）+ 常用学习包
6. 写入 shell 配置（清爽提示符、CUDA/uv 环境变量、自动激活 venv）
7. 跑一遍自检

完成后 **新开一个终端**，或：

```bash
source ~/.bashrc
```

---

## 手动步骤（脚本不可用时对照）

### 1. 确认 GPU 与 CUDA Toolkit

```bash
nvidia-smi          # 看 Driver / CUDA Version
nvcc --version      # 应为 12.4.x（或与教程匹配的 12.x）
```

本仓库学习路径按 **Toolkit 12.4** 编写。机器上通常已预装；缺 `nvcc` 时再按云厂商文档装 CUDA Toolkit，不必强行升级到 12.6+。

### 2. 系统依赖（C++ / Triton）

```bash
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential cmake ninja-build gdb ccache pkg-config \
  libeigen3-dev python3-dev
```

- `python3-dev`：Triton JIT 需要 `Python.h`，缺了会编译失败。
- `ninja` / `ccache`：CUDA CMake 工程编译更爽。

### 3. 安装 uv（国内网络）

```bash
# PyPI 清华源（GitHub 装 uv 常超时）
python3 -m pip install -U uv -i https://pypi.tuna.tsinghua.edu.cn/simple
mkdir -p ~/.local/bin
cp "$(python3 -c 'import shutil; print(shutil.which(\"uv\"))')" ~/.local/bin/uv
# 若系统没有可用 python3+pip，可改用官方安装脚本或镜像站发布的 uv 二进制
```

保证 `~/.local/bin` 在 `PATH` 里。

### 4. 创建 venv（大文件放数据盘）

```bash
export UV_CACHE_DIR=/root/autodl-tmp/uv-cache
export UV_DEFAULT_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple
mkdir -p /root/autodl-tmp/venvs "$UV_CACHE_DIR"

uv venv /root/autodl-tmp/venvs/cuda-learn --python /usr/bin/python3.10
ln -sfn /root/autodl-tmp/venvs/cuda-learn /path/to/InfraLearning/.venv
source /root/autodl-tmp/venvs/cuda-learn/bin/activate
```

没有 `/root/autodl-tmp` 时，把路径改成任意大磁盘，或直接用项目内 `.venv`。

### 5. 安装 PyTorch + Triton（必须指定 cu124 源）

```bash
uv pip install torch torchvision triton \
  --index-url https://download.pytorch.org/whl/cu124 \
  --index-strategy unsafe-best-match

# 其余学习包可用清华源
uv pip install numpy pandas matplotlib scipy \
  jupyterlab ipykernel tqdm pybind11 rich
```

验证：

```bash
python -c "import torch,triton; print(torch.__version__, torch.cuda.is_available(), triton.__version__)"
python examples/pytorch/hello.py
python examples/pytorch/triton_hello.py
```

编译 CUDA 样例：

```bash
cd examples/cuda
nvcc -O2 -arch=sm_89 -o hello hello.cu && ./hello
# 或：cmake -S . -B build -G Ninja && cmake --build build
```

`sm_89` 对应 RTX 4090；换卡时查 [CUDA GPU 架构](https://developer.nvidia.com/cuda-gpus) 改 `-arch`。

### 6. Shell 清爽配置

仓库脚本会写入标记块到 `~/.bashrc`（见 `scripts/shell_snippet.sh`），效果：

- 关闭 AutoDL 大段 MOTD（不再 `source /etc/autodl-motd`）
- 短提示符：`~/path (cuda-learn) ❯`
- `CUDA_HOME` / `LD_LIBRARY_PATH` / `uv` / 清华源
- 别名 `cuda-learn`；默认自动 `source` venv

AutoDL 的 `/etc/profile` 若仍把 `miniconda3` 放进 `PATH`，可改成包含 `~/.local/bin`（脚本在检测到时会尝试修正）。

---

## 目录约定

| 路径 | 用途 |
|------|------|
| `/`（系统盘，常约 30G） | 代码仓库、小工具 |
| `/root/autodl-tmp`（数据盘） | venv、uv cache、数据集、大编译产物 |
| `InfraLearning/.venv` | 软链 → 数据盘上的 `cuda-learn` venv |
| `examples/` | CUDA / PyTorch / Triton 冒烟样例 |
| `Kernels/` | 学习练习代码 |

---

## 日常命令速查

```bash
cuda-learn                          # 手动激活（若已自动激活可忽略）
uv pip install <pkg>                # 普通包
uv pip install torch torchvision triton \
  --index-url https://download.pytorch.org/whl/cu124 \
  --index-strategy unsafe-best-match   # 升级 torch 全家桶
uv cache clean                      # 清下载缓存，腾数据盘
```

---

## 常见问题

**1. `torch.cuda.is_available()` 为 False，提示 driver too old**  
装成了更高 CUDA 的 torch（如 cu130）。卸掉后按上面 cu124 命令重装。

**2. Triton：`Python.h: No such file`**  
`apt install python3-dev`（版本与 venv 的 3.10 对应）。

**3. `uv python install` / 官方 install.sh 卡住**  
国内拉 GitHub 常失败；本方案用**系统 Python 3.10 + pip 装 uv**，不依赖 `uv python install`。

**4. 系统盘满**  
venv / cache / 数据一律放到 `/root/autodl-tmp`；定期 `uv cache clean`。

**5. 与教程用 conda 还是 uv？**  
等价。教程里的 `uv add` / `uv sync` 在本环境用 `uv pip install` 即可；不要再装一份 conda，以免占双倍空间。

---

## 相关文件

- `scripts/setup_env.sh` — 一键配置
- `scripts/shell_snippet.sh` — 写入 `~/.bashrc` 的片段
- `pyproject.toml` — 依赖清单（torch 需按注释从 cu124 源装）
- `examples/pytorch/hello.py` / `triton_hello.py` / `examples/cuda/hello.cu` — 自检样例

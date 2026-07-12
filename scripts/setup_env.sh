#!/usr/bin/env bash
# InfraLearning — one-shot environment setup for a new GPU cloud box.
# Usage: bash scripts/setup_env.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_ROOT="${INFRA_DATA_ROOT:-/root/autodl-tmp}"
if [ ! -d "$DATA_ROOT" ]; then
  DATA_ROOT="${HOME}/infra-data"
  echo "[info] ${INFRA_DATA_ROOT:-/root/autodl-tmp} missing; using DATA_ROOT=${DATA_ROOT}"
fi

VENV="${DATA_ROOT}/venvs/cuda-learn"
UV_CACHE="${DATA_ROOT}/uv-cache"
PYTORCH_INDEX="${PYTORCH_INDEX:-https://download.pytorch.org/whl/cu124}"
UV_INDEX="${UV_DEFAULT_INDEX:-https://pypi.tuna.tsinghua.edu.cn/simple}"
PYTHON_BIN="${PYTHON_BIN:-/usr/bin/python3.10}"

export UV_CACHE_DIR="$UV_CACHE"
export UV_DEFAULT_INDEX="$UV_INDEX"
export INFRA_DATA_ROOT="$DATA_ROOT"
export PATH="${HOME}/.local/bin:${PATH}"

log() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# ----- 1. GPU / CUDA -----
log "Checking GPU and CUDA Toolkit"
command -v nvidia-smi >/dev/null || die "nvidia-smi not found (no NVIDIA driver?)"
command -v nvcc >/dev/null || die "nvcc not found — install CUDA Toolkit 12.4 first"
nvidia-smi --query-gpu=name,driver_version --format=csv,noheader || true
nvcc --version | tail -1

# ----- 2. apt packages -----
log "Installing system packages (C++ / Triton build deps)"
if command -v apt-get >/dev/null; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq \
    build-essential cmake ninja-build gdb ccache pkg-config \
    libeigen3-dev python3-dev python3-pip curl ca-certificates
else
  echo "[warn] apt-get not found; skip system packages — install gcc/cmake/ninja/python3-dev yourself"
fi

# ----- 3. uv -----
log "Installing uv into ~/.local/bin"
mkdir -p "${HOME}/.local/bin" "$UV_CACHE" "${DATA_ROOT}/venvs"
if ! command -v uv >/dev/null 2>&1; then
  python3 -m pip install -U uv -i "$UV_INDEX"
fi
UV_SRC="$(command -v uv || true)"
if [ -z "$UV_SRC" ]; then
  die "uv not found after pip install"
fi
cp -f "$UV_SRC" "${HOME}/.local/bin/uv"
chmod +x "${HOME}/.local/bin/uv"
hash -r 2>/dev/null || true
uv --version

# ----- 4. venv -----
log "Creating venv at ${VENV}"
if [ ! -x "$PYTHON_BIN" ]; then
  PYTHON_BIN="$(command -v python3)"
  echo "[warn] python3.10 not found; falling back to ${PYTHON_BIN}"
fi
uv venv "$VENV" --python "$PYTHON_BIN"
ln -sfn "$VENV" "${ROOT}/.venv"
# shellcheck disable=SC1091
source "${VENV}/bin/activate"

# ----- 5. PyTorch + Triton (cu124) + extras -----
log "Installing torch / torchvision / triton from ${PYTORCH_INDEX}"
uv pip install torch torchvision triton \
  --python "${VENV}/bin/python" \
  --index-url "$PYTORCH_INDEX" \
  --index-strategy unsafe-best-match

log "Installing learning extras from ${UV_INDEX}"
uv pip install \
  --python "${VENV}/bin/python" \
  -i "$UV_INDEX" \
  numpy pandas matplotlib scipy jupyterlab ipykernel tqdm pybind11 rich

# ----- 6. Shell config -----
log "Writing ~/.bashrc InfraLearning block"
BASHRC="${HOME}/.bashrc"
touch "$BASHRC"
# Disable AutoDL banner if present
sed -i 's|^[[:space:]]*source /etc/autodl-motd|# source /etc/autodl-motd  # disabled by InfraLearning|' "$BASHRC" || true

START_MARK="# >>> infra-learning >>>"
END_MARK="# <<< infra-learning <<<"
if grep -qF "$START_MARK" "$BASHRC" 2>/dev/null; then
  awk -v start="$START_MARK" -v end="$END_MARK" '
    $0 == start {skip=1; next}
    $0 == end {skip=0; next}
    !skip {print}
  ' "$BASHRC" > "${BASHRC}.tmp"
  mv "${BASHRC}.tmp" "$BASHRC"
fi
{
  echo ""
  echo "$START_MARK"
  echo "export INFRA_DATA_ROOT=\"${DATA_ROOT}\""
  cat "${ROOT}/scripts/shell_snippet.sh"
  echo "$END_MARK"
} >> "$BASHRC"

# AutoDL: prefer ~/.local/bin over removed miniconda in /etc/profile
if [ -f /etc/profile ] && grep -q 'miniconda3/bin' /etc/profile 2>/dev/null; then
  if [ -w /etc/profile ]; then
    sed -i 's|/root/miniconda3/bin:||g' /etc/profile
    if ! grep -q '\.local/bin' /etc/profile; then
      sed -i 's|^PATH=|PATH=/root/.local/bin:|' /etc/profile || true
    fi
    log "Updated /etc/profile PATH (removed miniconda3, ensured ~/.local/bin)"
  fi
fi

# ----- 7. Verify -----
log "Verifying PyTorch / Triton / CUDA"
"${VENV}/bin/python" - <<'PY'
import torch, triton
assert torch.cuda.is_available(), "CUDA not available for torch"
print(f"torch={torch.__version__}")
print(f"cuda={torch.version.cuda} device={torch.cuda.get_device_name(0)}")
print(f"triton={triton.__version__}")
x = torch.randn(1024, 1024, device="cuda")
print("matmul OK", float((x @ x).mean()))
PY

if [ -f "${ROOT}/examples/pytorch/triton_hello.py" ]; then
  "${VENV}/bin/python" "${ROOT}/examples/pytorch/triton_hello.py"
fi

log "Done."
echo "  venv:    ${VENV}"
echo "  link:    ${ROOT}/.venv"
echo "  docs:    ${ROOT}/docs/SETUP.md"
echo "Open a new terminal (or: source ~/.bashrc), then:"
echo "  python examples/pytorch/hello.py"
echo "  python examples/pytorch/triton_hello.py"

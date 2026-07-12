# Runtime env for InfraLearning. Requires INFRA_DATA_ROOT to be set above this block.

# --- History ---
HISTCONTROL=ignoreboth
HISTSIZE=5000
HISTFILESIZE=10000
shopt -s histappend checkwinsize 2>/dev/null || true

# --- Colors / ls ---
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi
alias ll='ls -lahF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'

# --- Prompt ---
__infra_prompt_venv() {
    if [ -n "${VIRTUAL_ENV:-}" ]; then
        printf ' (%s)' "$(basename "$VIRTUAL_ENV")"
    fi
}
PS1='\[\e[1;34m\]\w\[\e[0;36m\]$(__infra_prompt_venv)\[\e[0m\] ❯ '

# --- Completion ---
if [ -f /usr/share/bash-completion/bash_completion ]; then
    # shellcheck disable=SC1091
    . /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
    # shellcheck disable=SC1091
    . /etc/bash_completion
fi

# --- CUDA / C++ ---
export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"
export CUDA_PATH="${CUDA_PATH:-$CUDA_HOME}"
export PATH="/usr/lib/ccache:${CUDA_HOME}/bin:${PATH}"
export LD_LIBRARY_PATH="${CUDA_HOME}/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

# --- uv ---
export PATH="$HOME/.local/bin:${PATH}"
export UV_CACHE_DIR="${INFRA_DATA_ROOT}/uv-cache"
export UV_DEFAULT_INDEX="${UV_DEFAULT_INDEX:-https://pypi.tuna.tsinghua.edu.cn/simple}"

# --- Learning venv ---
export VIRTUAL_ENV_DISABLE_PROMPT=1
export INFRA_VENV="${INFRA_DATA_ROOT}/venvs/cuda-learn"
alias cuda-learn='source "${INFRA_VENV}/bin/activate"'
if [ -f "${INFRA_VENV}/bin/activate" ]; then
    # shellcheck disable=SC1091
    source "${INFRA_VENV}/bin/activate"
fi

# One-line status (replaces AutoDL full MOTD)
if command -v nvcc >/dev/null 2>&1; then
    printf '\e[2mgpu ready · cuda %s · uv\e[0m\n' \
        "$(nvcc --version 2>/dev/null | awk '/release/{print $NF}' | tr -d ',')"
fi

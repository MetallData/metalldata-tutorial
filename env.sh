# Source this before starting Python/Jupyter when NOT using the tutorial image.
#   source env.sh [path/to/metalldata/build/src/clippy]
export CLIPPY_BACKEND_PATH="${1:-${CLIPPY_BACKEND_PATH:-/src/build/src/clippy}}"
export CLIPPY_CMD_PREFIX="${CLIPPY_CMD_PREFIX:-mpirun -n 2}"
export MG_WORKDIR="${MG_WORKDIR:-/tmp/mg}"   # local disk; Metall uses mmap

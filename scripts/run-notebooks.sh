#!/usr/bin/env bash
# Execute every notebooks/*.md and write executed .ipynb into build/.
# Run inside the tutorial image (or anywhere CLIPPY_BACKEND_PATH is set).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
for nb in notebooks/*.md; do
  out="build/$(basename "${nb%.md}").ipynb"
  echo "=== executing $nb -> $out"
  (cd notebooks && jupytext --to ipynb --execute --output "../$out" "$(basename "$nb")")
done

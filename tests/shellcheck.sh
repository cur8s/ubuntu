#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd)"

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck \
    "$ROOT_DIR"/bin/* \
    "$ROOT_DIR"/install/*.sh \
    "$ROOT_DIR"/lib/*.sh \
    "$ROOT_DIR"/lab/lab-vm \
    "$ROOT_DIR"/lab/lib/*.sh \
    "$ROOT_DIR"/tests/*.sh
else
  while IFS= read -r -d '' script; do
    bash -n "$script"
  done < <(find "$ROOT_DIR/bin" "$ROOT_DIR/install" "$ROOT_DIR/lib" "$ROOT_DIR/lab" "$ROOT_DIR/tests" -name '*.sh' -print0)
fi

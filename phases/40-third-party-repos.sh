#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../lib/common.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/common.sh"

run_enabled_modules_step repo

if [ -n "${UBUNTU_APT_UPDATE_STAMP:-}" ]; then
  rm -f "$UBUNTU_APT_UPDATE_STAMP"
fi

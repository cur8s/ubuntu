#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../lib/common.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/common.sh"

run_enabled_modules_step install

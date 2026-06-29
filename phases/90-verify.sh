#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../lib/common.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/common.sh"
# shellcheck source=../lib/checks.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/checks.sh"

run_modules_step verify
finish_checks

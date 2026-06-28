#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../../lib/checks.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/checks.sh"

check_apt_package ufw
check_command ufw

if ufw status | grep -q '^Status: active'; then
  check_ok "ufw is active"
else
  check_fail "ufw is not active"
fi

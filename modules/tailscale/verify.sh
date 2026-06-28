#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../../lib/checks.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/checks.sh"

check_file /etc/apt/sources.list.d/tailscale.list
check_apt_package tailscale
check_command tailscale
check_systemd_unit tailscaled.service

if [ "${TAILSCALE_REQUIRE_CONNECTED:-0}" = "1" ]; then
  if tailscale status >/dev/null 2>&1; then
    check_ok "tailscale status is available"
  else
    check_fail "tailscale status is not available"
  fi
fi

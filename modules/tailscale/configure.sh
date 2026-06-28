#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../../lib/common.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/common.sh"
# shellcheck source=../../lib/systemd.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/systemd.sh"

systemd_enable_now tailscaled.service

if [ -n "${TAILSCALE_AUTHKEY:-}" ]; then
  log "joining Tailscale tailnet with provided auth key"
  # shellcheck disable=SC2086
  tailscale up --authkey "$TAILSCALE_AUTHKEY" ${TAILSCALE_UP_FLAGS:-}
else
  log "TAILSCALE_AUTHKEY is not set; tailscaled is installed but not joined"
fi

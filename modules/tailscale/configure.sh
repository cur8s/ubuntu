#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../../lib/common.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/common.sh"
# shellcheck source=../../lib/systemd.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/systemd.sh"

systemd_enable_now tailscaled.service

if tailscale status >/dev/null 2>&1; then
  log "tailscale is already connected"
  exit 0
fi

[ -n "${TAILSCALE_AUTHKEY:-}" ] || die "TAILSCALE_AUTHKEY is required to join Tailscale"

log "joining Tailscale tailnet with provided auth key"
# shellcheck disable=SC2086
tailscale up --authkey "$TAILSCALE_AUTHKEY" ${TAILSCALE_UP_FLAGS:-}

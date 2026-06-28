#!/usr/bin/env bash

# shellcheck source=common.sh
source "${UBUNTU_BOOTSTRAP_ROOT:?}/lib/common.sh"

systemd_available() {
  command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]
}

systemd_enable_now() {
  local unit="$1"

  if systemd_available; then
    log "systemctl enable --now $unit"
    systemctl enable --now "$unit"
  else
    warn "systemd is not available; skipping enable/start for $unit"
  fi
}

systemd_restart_if_active() {
  local unit="$1"

  if systemd_available && systemctl is-active --quiet "$unit"; then
    log "systemctl restart $unit"
    systemctl restart "$unit"
  fi
}

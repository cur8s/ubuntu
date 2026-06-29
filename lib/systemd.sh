#!/usr/bin/env bash

# shellcheck source=common.sh
source "${UBUNTU_BOOTSTRAP_ROOT:?}/lib/common.sh"

require_command systemctl

systemd_enable_now() {
  local unit="$1"

  log "systemctl enable --now $unit"
  systemctl enable --now "$unit"
}

systemd_restart_if_active() {
  local unit="$1"

  if systemctl is-active --quiet "$unit"; then
    log "systemctl restart $unit"
    systemctl restart "$unit"
  fi
}

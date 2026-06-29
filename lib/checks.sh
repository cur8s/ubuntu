#!/usr/bin/env bash

# shellcheck source=common.sh
source "${UBUNTU_BOOTSTRAP_ROOT:?}/lib/common.sh"

CHECK_FAILURES="${CHECK_FAILURES:-0}"

check_ok() {
  printf 'ok - %s\n' "$*"
}

check_fail() {
  printf 'not ok - %s\n' "$*" >&2
  CHECK_FAILURES=$((CHECK_FAILURES + 1))
}

check_command() {
  local command_name="$1"

  if command -v "$command_name" >/dev/null 2>&1; then
    check_ok "command exists: $command_name"
  else
    check_fail "command missing: $command_name"
  fi
}

check_file() {
  local path="$1"

  if [ -e "$path" ]; then
    check_ok "file exists: $path"
  else
    check_fail "file missing: $path"
  fi
}

check_apt_package() {
  local package_name="$1"

  if dpkg-query -W -f='${Status}' "$package_name" 2>/dev/null | grep -q 'install ok installed'; then
    check_ok "apt package installed: $package_name"
  else
    check_fail "apt package missing: $package_name"
  fi
}

check_systemd_unit() {
  local unit="$1"

  if systemctl is-enabled --quiet "$unit"; then
    check_ok "systemd unit enabled: $unit"
  else
    check_fail "systemd unit not enabled: $unit"
  fi
}

finish_checks() {
  if [ "$CHECK_FAILURES" -gt 0 ]; then
    die "$CHECK_FAILURES verification check(s) failed"
  fi
}

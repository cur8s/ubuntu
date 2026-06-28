#!/usr/bin/env bash

log() {
  printf '[ubuntu-bootstrap] %s\n' "$*"
}

warn() {
  printf '[ubuntu-bootstrap] warning: %s\n' "$*" >&2
}

die() {
  printf '[ubuntu-bootstrap] error: %s\n' "$*" >&2
  exit 1
}

bootstrap_root() {
  [ -n "${UBUNTU_BOOTSTRAP_ROOT:-}" ] || die "UBUNTU_BOOTSTRAP_ROOT is not set"
  printf '%s\n' "$UBUNTU_BOOTSTRAP_ROOT"
}

require_root() {
  [ "${EUID:-$(id -u)}" -eq 0 ] || die "run as root, usually with sudo"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

os_release_value() {
  local key="$1"

  [ -r /etc/os-release ] || return 1
  awk -F= -v key="$key" '
    $1 == key {
      value = $2
      gsub(/^"/, "", value)
      gsub(/"$/, "", value)
      print value
      exit
    }
  ' /etc/os-release
}

ubuntu_codename() {
  local codename

  codename="$(os_release_value VERSION_CODENAME || true)"
  if [ -n "$codename" ]; then
    printf '%s\n' "$codename"
    return 0
  fi

  require_command lsb_release
  lsb_release -sc
}

require_ubuntu() {
  local os_id

  os_id="$(os_release_value ID || true)"
  [ "$os_id" = "ubuntu" ] || die "this bootstrap only supports Ubuntu hosts"
}

load_profile() {
  local profile="$1"
  local root
  local profile_path

  root="$(bootstrap_root)"
  case "$profile" in
    */*) profile_path="$profile" ;;
    *) profile_path="$root/profiles/${profile}.conf" ;;
  esac

  [ -f "$profile_path" ] || die "profile not found: $profile"

  # shellcheck disable=SC1090
  source "$profile_path"
}

phase_path() {
  local phase="$1"
  local root

  root="$(bootstrap_root)"
  case "$phase" in
    *.sh) printf '%s/phases/%s\n' "$root" "$phase" ;;
    *) printf '%s/phases/%s.sh\n' "$root" "$phase" ;;
  esac
}

run_phase() {
  local phase="$1"
  local path

  path="$(phase_path "$phase")"
  [ -f "$path" ] || die "phase not found: $phase"

  log "phase: $phase"
  UBUNTU_BOOTSTRAP_CURRENT_PHASE="$phase" bash "$path"
}

module_enabled() {
  local module="$1"

  case " ${UBUNTU_BOOTSTRAP_MODULES:-} " in
    *" $module "*) return 0 ;;
    *) return 1 ;;
  esac
}

module_step_path() {
  local module="$1"
  local step="$2"
  local root

  root="$(bootstrap_root)"
  printf '%s/modules/%s/%s.sh\n' "$root" "$module" "$step"
}

run_module_step() {
  local module="$1"
  local step="$2"
  local required="${3:-optional}"
  local path

  module_enabled "$module" || return 0

  path="$(module_step_path "$module" "$step")"
  if [ ! -f "$path" ]; then
    if [ "$required" = "required" ]; then
      die "module step not found: $module/$step"
    fi

    log "skip module step: $module/$step"
    return 0
  fi

  log "module: $module/$step"
  UBUNTU_BOOTSTRAP_CURRENT_MODULE="$module" bash "$path"
}

run_enabled_modules_step() {
  local step="$1"
  local module

  for module in ${UBUNTU_BOOTSTRAP_MODULES:-}; do
    run_module_step "$module" "$step"
  done
}

write_file_if_changed() {
  local path="$1"
  local mode="${2:-0644}"
  local owner="${3:-root}"
  local group="${4:-root}"
  local tmp

  tmp="$(mktemp)"
  cat > "$tmp"

  if [ -f "$path" ] && cmp -s "$tmp" "$path"; then
    rm -f "$tmp"
    log "unchanged: $path"
    return 0
  fi

  install -D -m "$mode" -o "$owner" -g "$group" "$tmp" "$path"
  rm -f "$tmp"
  log "wrote: $path"
}

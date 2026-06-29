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
  [ -n "$codename" ] || die "could not detect Ubuntu codename from /etc/os-release"
  printf '%s\n' "$codename"
}

require_ubuntu() {
  local os_id
  local codename

  os_id="$(os_release_value ID || true)"
  [ "$os_id" = "ubuntu" ] || die "this bootstrap only supports Ubuntu hosts"

  codename="$(ubuntu_codename)"
  [ "$codename" = "noble" ] || die "this bootstrap only supports Ubuntu 24.04 LTS (noble), found: $codename"
}

configure_baseline() {
  UBUNTU_BOOTSTRAP_PHASES="00-preflight 10-base-system 40-third-party-repos 50-packages 60-services 90-verify"
  UBUNTU_BOOTSTRAP_MODULES="ssh firewall unattended-upgrades fail2ban tailscale osquery"
  UBUNTU_BOOTSTRAP_REPO_MODULES="tailscale osquery"

  SSH_PORT="${SSH_PORT:-22}"
  FIREWALL_ALLOW_TCP="${FIREWALL_ALLOW_TCP:-22}"
  TAILSCALE_UP_FLAGS="${TAILSCALE_UP_FLAGS:---ssh}"

  export UBUNTU_BOOTSTRAP_PHASES
  export UBUNTU_BOOTSTRAP_MODULES
  export UBUNTU_BOOTSTRAP_REPO_MODULES
  export SSH_PORT
  export FIREWALL_ALLOW_TCP
  export TAILSCALE_UP_FLAGS
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
  local path

  path="$(module_step_path "$module" "$step")"
  [ -f "$path" ] || die "module step not found: $module/$step"

  log "module: $module/$step"
  UBUNTU_BOOTSTRAP_CURRENT_MODULE="$module" bash "$path"
}

run_modules_step() {
  local step="$1"
  local module
  local modules

  case "$step" in
    repo) modules="${UBUNTU_BOOTSTRAP_REPO_MODULES:-}" ;;
    *) modules="${UBUNTU_BOOTSTRAP_MODULES:-}" ;;
  esac

  for module in $modules; do
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

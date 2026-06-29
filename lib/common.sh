#!/usr/bin/env bash

log() {
  printf '[ubuntu-bootstrap] %s\n' "$*"
}

die() {
  printf '[ubuntu-bootstrap] error: %s\n' "$*" >&2
  exit 1
}

require_root() {
  [ "${EUID:-$(id -u)}" -eq 0 ] || die "run as root, usually with sudo"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

os_release_value() {
  local key="$1"

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

require_ubuntu_2404() {
  local os_id
  local codename

  [ -r /etc/os-release ] || die "missing /etc/os-release"

  os_id="$(os_release_value ID)"
  codename="$(os_release_value VERSION_CODENAME)"

  [ "$os_id" = "ubuntu" ] || die "this bootstrap only supports Ubuntu"
  [ "$codename" = "noble" ] || die "this bootstrap only supports Ubuntu 24.04 LTS (noble), found: $codename"
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

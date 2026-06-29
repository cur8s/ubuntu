#!/usr/bin/env bash

# shellcheck source=common.sh
source "${UBUNTU_BOOTSTRAP_ROOT:?}/lib/common.sh"

apt_update_once() {
  if [ "${UBUNTU_APT_UPDATED:-0}" = "1" ]; then
    return 0
  fi

  if [ -n "${UBUNTU_APT_UPDATE_STAMP:-}" ] && [ -f "$UBUNTU_APT_UPDATE_STAMP" ]; then
    return 0
  fi

  log "apt-get update"
  DEBIAN_FRONTEND=noninteractive apt-get update
  export UBUNTU_APT_UPDATED=1

  if [ -n "${UBUNTU_APT_UPDATE_STAMP:-}" ]; then
    touch "$UBUNTU_APT_UPDATE_STAMP"
  fi
}

apt_install_packages() {
  [ "$#" -gt 0 ] || return 0

  apt_update_once
  log "apt-get install: $*"
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@"
}

apt_install_keyring_from_url() {
  local name="$1"
  local url="$2"
  local format="${3:-auto}"
  local dest="/usr/share/keyrings/${name}-archive-keyring.gpg"
  local download_tmp
  local keyring_tmp

  require_command curl
  mkdir -p --mode=0755 /usr/share/keyrings
  download_tmp="$(mktemp)"
  keyring_tmp="$(mktemp)"

  curl -fsSL "$url" > "$download_tmp"

  case "$format" in
    auto)
      if grep -q 'BEGIN PGP PUBLIC KEY BLOCK' "$download_tmp"; then
        require_command gpg
        gpg --dearmor < "$download_tmp" > "$keyring_tmp"
      else
        cp "$download_tmp" "$keyring_tmp"
      fi
      ;;
    armored)
      require_command gpg
      gpg --dearmor < "$download_tmp" > "$keyring_tmp"
      ;;
    binary)
      cp "$download_tmp" "$keyring_tmp"
      ;;
    *)
      rm -f "$download_tmp" "$keyring_tmp"
      die "unsupported keyring format: $format"
      ;;
  esac

  install -m 0644 "$keyring_tmp" "$dest"
  rm -f "$download_tmp" "$keyring_tmp"
  log "installed keyring: $dest"
}

apt_write_source() {
  local name="$1"
  local source_line="$2"
  local dest="/etc/apt/sources.list.d/${name}.list"

  printf '%s\n' "$source_line" | write_file_if_changed "$dest" 0644 root root
}

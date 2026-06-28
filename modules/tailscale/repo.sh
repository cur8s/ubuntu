#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../../lib/common.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/common.sh"
# shellcheck source=../../lib/apt.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/apt.sh"

codename="$(ubuntu_codename)"
key_url="${TAILSCALE_KEY_URL:-https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg}"
list_url="${TAILSCALE_LIST_URL:-https://pkgs.tailscale.com/stable/ubuntu/${codename}.tailscale-keyring.list}"
tmp="$(mktemp)"

apt_install_keyring_from_url tailscale "$key_url" binary

require_command curl
curl -fsSL "$list_url" > "$tmp"
install -D -m 0644 "$tmp" /etc/apt/sources.list.d/tailscale.list
rm -f "$tmp"

log "installed Tailscale APT source for Ubuntu $codename"

#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../../lib/common.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/common.sh"

require_command ufw

ufw default deny incoming
ufw default allow outgoing

for port in ${FIREWALL_ALLOW_TCP:-22}; do
  ufw allow "${port}/tcp"
done

ufw --force enable

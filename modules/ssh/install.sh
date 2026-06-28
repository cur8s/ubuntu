#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../../lib/apt.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/apt.sh"

apt_install_packages openssh-server

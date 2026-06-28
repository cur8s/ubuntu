#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../lib/common.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/common.sh"
# shellcheck source=../lib/apt.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/apt.sh"

apt_install_packages \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  sudo

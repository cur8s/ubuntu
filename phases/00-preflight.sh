#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../lib/common.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/common.sh"

require_root
require_ubuntu
require_command apt-get
require_command systemctl

codename="$(ubuntu_codename)"
log "detected Ubuntu codename: $codename"

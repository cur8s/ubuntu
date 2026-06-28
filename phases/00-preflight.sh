#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../lib/common.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/common.sh"

require_root
require_ubuntu
require_command apt-get

codename="$(ubuntu_codename)"
log "detected Ubuntu codename: $codename"

if [ -n "${UBUNTU_TARGET_CODENAME:-}" ] && [ "$codename" != "$UBUNTU_TARGET_CODENAME" ]; then
  die "expected Ubuntu codename '$UBUNTU_TARGET_CODENAME', found '$codename'"
fi

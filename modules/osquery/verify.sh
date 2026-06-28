#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../../lib/checks.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/checks.sh"

check_file /etc/apt/sources.list.d/osquery.list
check_file /etc/osquery/osquery.conf
check_apt_package osquery
check_command osqueryi
check_systemd_unit osqueryd.service

#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../../lib/checks.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/checks.sh"

check_apt_package unattended-upgrades
check_file /etc/apt/apt.conf.d/20auto-upgrades
check_file /etc/apt/apt.conf.d/52unattended-upgrades-production

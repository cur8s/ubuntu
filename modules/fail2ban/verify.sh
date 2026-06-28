#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../../lib/checks.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/checks.sh"

check_apt_package fail2ban
check_file /etc/fail2ban/jail.d/sshd-production.conf
check_systemd_unit fail2ban.service

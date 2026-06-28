#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../../lib/common.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/common.sh"
# shellcheck source=../../lib/systemd.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/systemd.sh"

write_file_if_changed /etc/fail2ban/jail.d/sshd-production.conf 0644 root root <<'EOF'
[sshd]
enabled = true
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
EOF

systemd_enable_now fail2ban.service

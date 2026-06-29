#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../../lib/common.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/common.sh"
# shellcheck source=../../lib/systemd.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/systemd.sh"

sshd_config_dir="/etc/ssh/sshd_config.d"
mkdir -p "$sshd_config_dir"

write_file_if_changed "$sshd_config_dir/10-production-baseline.conf" 0644 root root <<EOF
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
X11Forwarding no
AllowTcpForwarding yes
ClientAliveInterval 300
ClientAliveCountMax 2
Port ${SSH_PORT:-22}
EOF

sshd -t
systemd_restart_if_active ssh.service

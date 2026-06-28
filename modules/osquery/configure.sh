#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../../lib/common.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/common.sh"
# shellcheck source=../../lib/systemd.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/systemd.sh"

write_file_if_changed /etc/osquery/osquery.conf 0644 root root <<'JSON'
{
  "options": {
    "config_plugin": "filesystem",
    "logger_plugin": "filesystem",
    "disable_events": "false"
  },
  "schedule": {
    "system_info": {
      "query": "SELECT hostname, cpu_brand, physical_memory FROM system_info;",
      "interval": 3600
    },
    "listening_ports": {
      "query": "SELECT pid, port, protocol, address FROM listening_ports;",
      "interval": 3600
    }
  }
}
JSON

systemd_enable_now osqueryd.service

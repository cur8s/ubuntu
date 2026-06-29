#!/usr/bin/env bash
set -Eeuo pipefail

# Trust packages signed by osquery.
curl -fsSL https://pkg.osquery.io/deb/pubkey.gpg \
  | gpg --dearmor \
  > /usr/share/keyrings/osquery-archive-keyring.gpg

# Add the osquery package source.
cat > /etc/apt/sources.list.d/osquery.list <<'EOF'
deb [arch=amd64 signed-by=/usr/share/keyrings/osquery-archive-keyring.gpg] https://pkg.osquery.io/deb deb main
EOF

# Refresh package metadata and install osquery.
apt-get update
apt-get install -y osquery

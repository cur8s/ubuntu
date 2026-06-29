#!/usr/bin/env bash
set -Eeuo pipefail

# Trust packages signed by CISOfy.
curl -fsSL https://packages.cisofy.com/keys/cisofy-software-public.key \
  | gpg --dearmor \
  > /usr/share/keyrings/cisofy-software-public.gpg

# Add the Lynis community package source.
cat > /etc/apt/sources.list.d/cisofy-lynis.list <<'EOF'
deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/cisofy-software-public.gpg] https://packages.cisofy.com/community/lynis/deb/ stable main
EOF

# Refresh package metadata and install Lynis.
apt-get update
apt-get install -y lynis

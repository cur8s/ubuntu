#!/usr/bin/env bash
set -Eeuo pipefail

POSTGRES_VERSION="${POSTGRES_VERSION:-18}"

# Trust packages signed by the PostgreSQL Apt Repository.
install -d /usr/share/postgresql-common/pgdg
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
  > /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc

# Add the PostgreSQL Apt Repository for Ubuntu 24.04.
cat > /etc/apt/sources.list.d/pgdg.sources <<EOF
Types: deb
URIs: https://apt.postgresql.org/pub/repos/apt
Suites: noble-pgdg
Architectures: $(dpkg --print-architecture)
Components: main
Signed-By: /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc
EOF

# Refresh package metadata and install the selected PostgreSQL version.
apt-get update
apt-get install -y "postgresql-${POSTGRES_VERSION}"

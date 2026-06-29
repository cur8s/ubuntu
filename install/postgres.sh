#!/usr/bin/env bash
set -Eeuo pipefail

# Install PostgreSQL from Ubuntu 24.04 packages.
apt-get update
apt-get install -y postgresql

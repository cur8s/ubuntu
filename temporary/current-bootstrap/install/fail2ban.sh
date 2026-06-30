#!/usr/bin/env bash
set -Eeuo pipefail

# Install Fail2ban from Ubuntu 24.04 packages.
apt-get update
apt-get install -y fail2ban

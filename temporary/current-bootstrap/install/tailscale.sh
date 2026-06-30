#!/usr/bin/env bash
set -Eeuo pipefail

# Trust packages signed by Tailscale.
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg \
  > /usr/share/keyrings/tailscale-archive-keyring.gpg

# Add the Tailscale package source for Ubuntu 24.04.
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list \
  > /etc/apt/sources.list.d/tailscale.list

# Refresh package metadata and install Tailscale.
apt-get update
apt-get install -y tailscale

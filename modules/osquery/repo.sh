#!/usr/bin/env bash
set -Eeuo pipefail

: "${UBUNTU_BOOTSTRAP_ROOT:?}"

# shellcheck source=../../lib/common.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/common.sh"
# shellcheck source=../../lib/apt.sh
source "$UBUNTU_BOOTSTRAP_ROOT/lib/apt.sh"

architecture="${OSQUERY_APT_ARCHITECTURE:-amd64}"
key_url="${OSQUERY_KEY_URL:-https://pkg.osquery.io/deb/pubkey.gpg}"
repo_url="${OSQUERY_REPO_URL:-https://pkg.osquery.io/deb}"
repo_suite="${OSQUERY_REPO_SUITE:-deb}"
repo_component="${OSQUERY_REPO_COMPONENT:-main}"

apt_install_keyring_from_url osquery "$key_url" auto
apt_write_source osquery "deb [arch=${architecture} signed-by=/usr/share/keyrings/osquery-archive-keyring.gpg] ${repo_url} ${repo_suite} ${repo_component}"

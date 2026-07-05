# Shared helpers for this folder's mise tasks. Deliberately NOT executable:
# mise only detects executable files as tasks, so this stays a library.
# (Corollary: new task scripts MUST be chmod +x or mise silently ignores
# them.) The folder is self-contained on purpose — it never sources
# anything outside itself, so it keeps working when copied out of the
# cur8s/ubuntu repository.

droplet_ip() {
  doctl compute droplet list "$DROPLET_NAME" --format PublicIPv4 --no-header
}

# droplet_ip, but fail loudly when no droplet exists. droplet_ip itself
# stays empty-on-absent for the callers that want absence (vm:ip,
# vm:status, the integration test's preflight); everything that is about
# to SSH somewhere goes through this.
droplet_ip_required() {
  _required_addr="$(droplet_ip)"
  if [ -z "$_required_addr" ]; then
    echo "No droplet named $DROPLET_NAME exists (create one: mise run up)." >&2
    exit 1
  fi
  printf '%s' "$_required_addr"
}

# Preamble for SSH-heavy tasks: optional IPS spacing + ansible temp dir.
ssh_task_preamble() {
  sleep "${SSH_SPACING_SECONDS:-0}"
  mkdir -p "$ANSIBLE_LOCAL_TEMP"
}

# Where the installed collection lives (see requirements.yml; inside the
# cur8s/ubuntu repository the root test:integration tasks symlink the working tree here).
collection_dir() {
  printf '%s' "$ANSIBLE_COLLECTIONS_PATH/ansible_collections/cur8s/ubuntu"
}

# Install the collection if absent. Loud on install: a fresh install pulls
# the pinned source from requirements.yml, never a local working tree.
ensure_collection() {
  if [ ! -e "$(collection_dir)" ]; then
    echo "Installing cur8s.ubuntu from requirements.yml (the pinned source)..."
    ansible-galaxy collection install -r "$MISE_CONFIG_ROOT/requirements.yml" \
      -p "$ANSIBLE_COLLECTIONS_PATH"
    echo "Installed the pinned collection. (Developing cur8s.ubuntu itself?"
    echo "Run 'mise run test:integration:link-digital-ocean' at the repo root to use the working tree.)"
  fi
}

# Run one of the collection's playbooks against the droplet by FQCN:
# droplet_playbook <playbook-name> [ansible-playbook args...]
droplet_playbook() {
  _playbook="cur8s.ubuntu.$1"
  shift
  ensure_collection
  # Assignment, not argument-position substitution: under set -e a failed
  # substitution in an argument is masked; in an assignment it aborts.
  _playbook_addr="$(droplet_ip_required)"
  ansible-playbook -i "$_playbook_addr," "$_playbook" "$@"
}

# Interactive SSH to the droplet: droplet_ssh <user> <public-key-file>
# The identity file is the PUBLIC key: ssh offers it and the vault's SSH
# agent signs — the private half never touches disk.
droplet_ssh() {
  _ssh_addr="$(droplet_ip_required)"
  exec ssh \
    -o UserKnownHostsFile="$MISE_CONFIG_ROOT/.generated/known_hosts" \
    -o StrictHostKeyChecking=accept-new \
    -o IdentitiesOnly=yes \
    -i "$2" \
    "$1@$_ssh_addr"
}

# Block until cloud-init reports done, riding across the first-boot reboot.
# $1 names a probe function that runs a remote command on the droplet (the
# remote command is appended as arguments). Timeout is
# CLOUD_INIT_WAIT_TIMEOUT_SECONDS (default 1200).
wait_for_cloud_init() {
  _wait_probe="$1"
  _wait_deadline=$(( $(date +%s) + ${CLOUD_INIT_WAIT_TIMEOUT_SECONDS:-1200} ))

  _wait_until_done() {
    until "$_wait_probe" cloud-init status --wait >/dev/null 2>&1; do
      # A reachable host whose cloud-init landed in the error state will
      # never turn done: fail now instead of spinning out the deadline.
      if "$_wait_probe" cloud-init status 2>/dev/null | grep -q 'status: error'; then
        echo "cloud-init finished in the error state; inspect the host's /var/log/cloud-init.log." >&2
        exit 1
      fi
      if [ "$(date +%s)" -ge "$_wait_deadline" ]; then
        echo "Timed out waiting for cloud-init to finish." >&2
        exit 1
      fi
      sleep 10
    done
  }

  echo "Waiting for cloud-init to finish (first boot dist-upgrades; this takes minutes)..."
  _wait_until_done
  # The first-boot power_state reboot fires the moment cloud-init reports
  # done, so a success here may be the pre-reboot instance. Let the reboot
  # land, then require done again on the far side; on a settled VM the
  # second pass returns immediately.
  sleep 15
  _wait_until_done
  echo "cloud-init is done; the droplet is ready."
}

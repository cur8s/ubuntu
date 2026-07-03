# Shared helpers for the mise file tasks. Deliberately NOT executable:
# mise only detects executable files as tasks, so this stays a library.
# (Corollary: new task scripts MUST be chmod +x or mise silently ignores them.)

droplet_ip() {
  doctl compute droplet list "$DROPLET_NAME" --format PublicIPv4 --no-header
}

# Preamble for SSH-heavy tasks: optional IPS spacing + ansible temp dir.
ssh_task_preamble() {
  sleep "${SSH_SPACING_SECONDS:-0}"
  mkdir -p "$ANSIBLE_LOCAL_TEMP"
}

# Interactive SSH to the droplet: droplet_ssh <user> <identity-file>
droplet_ssh() {
  exec ssh \
    -o StrictHostKeyChecking=accept-new \
    -o IdentitiesOnly=yes \
    -i "$2" \
    "$1@$(droplet_ip)"
}

# Inventory for the local QEMU VM (regenerated on use so QEMU_* env stays
# authoritative). A named alias is load-bearing: an inventory host literally
# named 127.0.0.1 is treated as a localhost alias, so `hosts: localhost`
# plays and `delegate_to: localhost` tasks would SSH into the VM instead of
# running locally.
qemu_inventory() {
  printf '%s ansible_host=127.0.0.1 ansible_port=%s\n' "$QEMU_VM_NAME" "$QEMU_SSH_PORT" \
    > "$QEMU_VM_DIR/inventory"
  printf '%s' "$QEMU_VM_DIR/inventory"
}

# Run a playbook against the local QEMU VM: qemu_ansible_playbook <playbook> [args...]
qemu_ansible_playbook() {
  ANSIBLE_SSH_COMMON_ARGS="-o UserKnownHostsFile=$QEMU_VM_DIR/known_hosts -o StrictHostKeyChecking=accept-new" \
    ansible-playbook -i "$(qemu_inventory)" "$@"
}

# Run one example against a target lab: example_run <example> <do|qemu>
example_run() {
  _example_playbook="$MISE_CONFIG_ROOT/examples/$1/site.yml"
  (
    export ANSIBLE_COLLECTIONS_PATH="$MISE_CONFIG_ROOT/.generated/collections"
    case "$2" in
      do) ansible-playbook -i "$(droplet_ip)," "$_example_playbook" ;;
      qemu) qemu_ansible_playbook "$_example_playbook" ;;
      *)
        echo "Unknown example target '$2' (expected do or qemu)." >&2
        exit 1
        ;;
    esac
  )
}

# Block until cloud-init reports done, riding across the first-boot reboot.
# $1 names a probe function that runs a remote command on the lab VM (the
# remote command is appended as arguments). Timeout is
# CLOUD_INIT_WAIT_TIMEOUT_SECONDS (default 1200).
wait_for_cloud_init() {
  _wait_probe="$1"
  _wait_deadline=$(( $(date +%s) + ${CLOUD_INIT_WAIT_TIMEOUT_SECONDS:-1200} ))

  _wait_until_done() {
    until "$_wait_probe" cloud-init status --wait >/dev/null 2>&1; do
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
  echo "cloud-init is done; the VM is ready."
}

# Run every example twice against a lab: example_run_all <do|qemu>.
# The examples' contract: the second run is a full no-op. Second-run output
# goes to a log so a clean pass stays quiet; recap lines are the only place
# ansible prints "changed=N", so grepping the log for a non-zero count is
# exact.
example_run_all() {
  _run_all_target="$1"
  _run_all_skipped=""

  for _example_dir in "$MISE_CONFIG_ROOT/examples"/*/; do
    _example_name="$(basename "$_example_dir")"
    [ -f "$_example_dir/site.yml" ] || continue

    if [ "$_example_name" = "tailscale" ] && [ -z "${TAILSCALE_AUTHKEY:-}" ]; then
      echo "SKIP tailscale: TAILSCALE_AUTHKEY is not set. (Joining also leaves a node"
      echo "in the tailnet admin console unless the auth key is ephemeral.)"
      _run_all_skipped="$_run_all_skipped tailscale"
      continue
    fi

    echo "==> $_example_name ($_run_all_target): first run"
    example_run "$_example_name" "$_run_all_target"

    echo "==> $_example_name ($_run_all_target): second run (idempotency contract: changed=0)"
    _second_log="$ANSIBLE_LOCAL_TEMP/example-run-all-$_example_name.log"
    if ! example_run "$_example_name" "$_run_all_target" > "$_second_log" 2>&1; then
      cat "$_second_log"
      echo "FAIL $_example_name: second run failed." >&2
      exit 1
    fi
    if grep -qE 'changed=[1-9]' "$_second_log"; then
      grep -A9 "PLAY RECAP" "$_second_log" || cat "$_second_log"
      echo "FAIL $_example_name: second run reported changes." >&2
      exit 1
    fi
    grep -hA3 "PLAY RECAP" "$_second_log" | sed "s/^/    /"
  done

  echo "All examples passed twice on $_run_all_target.${_run_all_skipped:+ Skipped:$_run_all_skipped.}"
}

# SSH to the local QEMU VM: qemu_ssh <user> <identity-file> [command...]
# Each fresh VM presents new host keys on the same forwarded port, so the
# known_hosts file lives in the VM state dir and dies with it.
qemu_ssh() {
  _qemu_ssh_user="$1"
  _qemu_ssh_identity="$2"
  shift 2
  ssh \
    -o UserKnownHostsFile="$QEMU_VM_DIR/known_hosts" \
    -o StrictHostKeyChecking=accept-new \
    -o IdentitiesOnly=yes \
    -o ConnectTimeout=10 \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=4 \
    -i "$_qemu_ssh_identity" \
    -p "$QEMU_SSH_PORT" \
    "$_qemu_ssh_user@127.0.0.1" "$@"
}

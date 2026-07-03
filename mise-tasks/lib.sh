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

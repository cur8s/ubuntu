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

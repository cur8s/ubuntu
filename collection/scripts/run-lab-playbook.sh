# run-lab-playbook.sh — run a cur8s.ubuntu playbook against the lab VM.
#
# Ships with the collection because it is the other half of the lab
# contract activate-test-credentials.sh implements: the connection
# environment for pub-as-identity custody (RFC-004) against a VM built
# by the vendored qemu-vm.sh, whose known_hosts and inventory live in
# the VM's own state directory and die with it.
#
# Usage, from a consumer harness (cur8s/ubuntu's mise tasks, a k3s
# repo's lab, ...): source this file from bash, then
#   run_lab_playbook <playbook> [ansible-playbook args...]
# Sourcing also brings in the sibling activate-test-credentials.sh.
# Deliberately not executable — it defines functions for the caller's
# shell.
#
# Requires: QVM_DIR, QVM_NAME, QVM_SSH_PORT (the vendored harness's
#           env) and QEMU_KEYS_DIR (the shim's). Targets the
#           cur8s/qemu contract — QVM_* env, known_hosts in the VM
#           state dir — and needs qemu-vm.sh >= 0.3.0 (the version
#           that honors QVM_SSH_IDENTITY_AGENT).
# Optional: ANSIBLE_LOCAL_TEMP — created if set (ansible does not
#           create a custom local tmp dir on its own).

. "$(dirname "${BASH_SOURCE[0]}")/activate-test-credentials.sh"

# Write the lab inventory (regenerated on use so QVM_* env stays
# authoritative) and print its path. A named alias is load-bearing: an
# inventory host literally named 127.0.0.1 is treated as a localhost
# alias, so `hosts: localhost` plays and `delegate_to: localhost`
# tasks would SSH into the VM instead of running locally.
write_lab_inventory() {
  printf '%s ansible_host=127.0.0.1 ansible_port=%s\n' "$QVM_NAME" "$QVM_SSH_PORT" \
    > "$QVM_DIR/inventory"
  printf '%s' "$QVM_DIR/inventory"
}

# Activates the test credentials first, so playbooks that read
# *_PUB_KEY resolve the throwaway test keys, never the vault's.
run_lab_playbook() {
  if [[ ! -d $QVM_DIR ]]; then
    echo "No lab VM exists at $QVM_DIR (build and start one first)." >&2
    return 1
  fi
  activate_test_credentials
  [[ -z ${ANSIBLE_LOCAL_TEMP:-} ]] || mkdir -p "$ANSIBLE_LOCAL_TEMP"
  # IdentityAgent is pinned explicitly: a secrets manager's ~/.ssh/config
  # sets a global IdentityAgent (it overrides even SSH_AUTH_SOCK), and
  # without the pin lab traffic would consult that agent and prompt.
  # The VALIDATE_SSH_IDENTITY_AGENT export makes the collection's
  # validation probe pin the same lab agent (by default the probe
  # follows the user's ssh config, which is right everywhere except a
  # lab).
  VALIDATE_SSH_IDENTITY_AGENT="$QEMU_KEYS_DIR/agent.sock" \
    ANSIBLE_SSH_COMMON_ARGS="-o UserKnownHostsFile=$QVM_DIR/known_hosts -o StrictHostKeyChecking=accept-new -o IdentityAgent=$QEMU_KEYS_DIR/agent.sock" \
    ansible-playbook -i "$(write_lab_inventory)" "$@"
}

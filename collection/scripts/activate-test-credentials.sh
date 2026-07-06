# activate-test-credentials.sh — the cur8s.ubuntu test-credential shim.
#
# Ships with the collection because it implements the collection's
# custody contract (RFC-004: Identity and Trust): playbooks connect
# pub-as-identity — configuration never holds private keys — and
# OpenSSH resolves a .pub identity only through an agent. In
# production that agent is the operator's secrets manager; in a local
# lab it is the promptless throwaway agent this shim maintains.
# Without one, ssh tries the .pub as a private key and fails
# ("invalid format").
#
# Usage, from a consumer harness (cur8s/ubuntu's mise tasks, a k3s
# repo's lab, ...): source this file from bash, then call
# activate_test_credentials before anything that SSHes. Deliberately not
# executable — it defines one function and must run in the caller's
# shell so the exports land there.
#
# Requires: QEMU_KEYS_DIR — where the keypairs and agent.sock live
#           (git-ignored workstation state; dies with the lab).
# Exports:  BOOTSTRAP_PUB_KEY, ANSIBLE_PUB_KEY, SYSADMIN_PUB_KEY,
#           SSH_AUTH_SOCK, and QVM_SSH_IDENTITY_AGENT — the last so a
#           vendored qemu-vm.sh's ssh verb signs through this agent.

# Make the test credentials operational in this shell: generate
# missing keypairs, ensure the promptless ssh-agent is up, and export
# the env vars above. They open nothing but a disposable VM on a
# loopback port, live git-ignored, and die with the lab state —
# RFC-004 calls them test fixtures, not credentials.
activate_test_credentials() {
  local key
  for key in ubuntu-bootstrap ubuntu-ansible ubuntu-sysadmin; do
    if [[ ! -f "$QEMU_KEYS_DIR/$key" ]]; then
      mkdir -p "$QEMU_KEYS_DIR"
      ssh-keygen -q -t ed25519 -N '' -C "qemu-lab-$key" -f "$QEMU_KEYS_DIR/$key"
      # 0600 like vault-extracted pubs: ssh tries identity files as
      # private keys first and refuses world-readable ones.
      chmod 600 "$QEMU_KEYS_DIR/$key.pub"
    fi
  done

  # The dedicated, promptless agent that signs for the .pub identities.
  local sock="$QEMU_KEYS_DIR/agent.sock" agent_state=0
  SSH_AUTH_SOCK="$sock" ssh-add -l >/dev/null 2>&1 || agent_state=$?
  if [[ $agent_state -eq 2 ]]; then
    # No agent behind the socket (never started, or stale after a reboot).
    rm -f "$sock"
    ssh-agent -a "$sock" >/dev/null
  fi
  if [[ $agent_state -ne 0 ]]; then
    SSH_AUTH_SOCK="$sock" ssh-add -q \
      "$QEMU_KEYS_DIR/ubuntu-bootstrap" \
      "$QEMU_KEYS_DIR/ubuntu-ansible" \
      "$QEMU_KEYS_DIR/ubuntu-sysadmin"
  fi
  export SSH_AUTH_SOCK="$sock"
  export QVM_SSH_IDENTITY_AGENT="$sock"

  export BOOTSTRAP_PUB_KEY="$QEMU_KEYS_DIR/ubuntu-bootstrap.pub"
  export ANSIBLE_PUB_KEY="$QEMU_KEYS_DIR/ubuntu-ansible.pub"
  export SYSADMIN_PUB_KEY="$QEMU_KEYS_DIR/ubuntu-sysadmin.pub"
}

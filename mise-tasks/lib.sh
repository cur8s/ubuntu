# Shared helpers for the mise file tasks. Deliberately NOT executable:
# mise only detects executable files as tasks, so this stays a library.
# (Corollary: new task scripts MUST be chmod +x or mise silently ignores them.)

# Preamble for SSH-heavy tasks: optional IPS spacing + ansible temp dir.
ssh_task_preamble() {
  sleep "${SSH_SPACING_SECONDS:-0}"
  mkdir -p "$ANSIBLE_LOCAL_TEMP"
}

# Point the key env vars at the QEMU lab's throwaway keypairs, generating
# them on first use (RFC-004: ephemeral lab credentials — they open nothing
# but a disposable VM on a loopback port, live git-ignored, and die with
# `clean`). Private keys sit next to their .pub, so every existing
# `-i <pubfile>` mechanic works without the 1Password agent: ssh uses the
# adjacent private file. The DigitalOcean integration folder never calls
# this and keeps the vault-held keys.
qemu_keys_env() {
  for _lab_key in ubuntu-bootstrap ubuntu-ansible ubuntu-sysadmin; do
    if [ ! -f "$QEMU_KEYS_DIR/$_lab_key" ]; then
      mkdir -p "$QEMU_KEYS_DIR"
      ssh-keygen -q -t ed25519 -N '' -C "qemu-lab-$_lab_key" -f "$QEMU_KEYS_DIR/$_lab_key"
      # 0600 like the vault-extracted pubs: ssh tries identity files as
      # private keys first and refuses world-readable ones.
      chmod 600 "$QEMU_KEYS_DIR/$_lab_key.pub"
    fi
  done

  # A dedicated, promptless ssh-agent holds the lab keys, so every
  # pub-as-identity mechanic (`-i <file>.pub`) works exactly as it does
  # against 1Password — the lab merely substitutes its own agent.
  _lab_sock="$QEMU_KEYS_DIR/agent.sock"
  _lab_agent_state=0
  SSH_AUTH_SOCK="$_lab_sock" ssh-add -l >/dev/null 2>&1 || _lab_agent_state=$?
  if [ "$_lab_agent_state" -eq 2 ]; then
    # No agent behind the socket (never started, or stale after a reboot).
    rm -f "$_lab_sock"
    ssh-agent -a "$_lab_sock" >/dev/null
  fi
  if [ "$_lab_agent_state" -ne 0 ]; then
    SSH_AUTH_SOCK="$_lab_sock" ssh-add -q \
      "$QEMU_KEYS_DIR/ubuntu-bootstrap" \
      "$QEMU_KEYS_DIR/ubuntu-ansible" \
      "$QEMU_KEYS_DIR/ubuntu-sysadmin"
  fi
  export SSH_AUTH_SOCK="$_lab_sock"

  export BOOTSTRAP_PUB_KEY="$QEMU_KEYS_DIR/ubuntu-bootstrap.pub"
  export ANSIBLE_PUB_KEY="$QEMU_KEYS_DIR/ubuntu-ansible.pub"
  export SYSADMIN_PUB_KEY="$QEMU_KEYS_DIR/ubuntu-sysadmin.pub"
  export CLOUD_INIT_FILE="$QEMU_CLOUD_INIT_FILE"
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
# Exports the lab key env first, so playbooks that read *_PUB_KEY resolve
# the throwaway lab keys, never the vault's.
qemu_ansible_playbook() {
  if [ ! -d "$QEMU_VM_DIR" ]; then
    echo "No local QEMU VM exists (mise run qemu:up)." >&2
    return 1
  fi
  qemu_keys_env
  # IdentityAgent is pinned explicitly: 1Password's ~/.ssh/config sets a
  # global IdentityAgent, which overrides SSH_AUTH_SOCK — without the pin,
  # lab traffic would consult the 1Password agent and prompt. The
  # VALIDATE_SSH_IDENTITY_AGENT export makes the collection's validation
  # probe pin the same lab agent (by default the probe follows the user's
  # ssh config, which is right everywhere except this lab).
  VALIDATE_SSH_IDENTITY_AGENT="$QEMU_KEYS_DIR/agent.sock" \
    ANSIBLE_SSH_COMMON_ARGS="-o UserKnownHostsFile=$QEMU_VM_DIR/known_hosts -o StrictHostKeyChecking=accept-new -o IdentityAgent=$QEMU_KEYS_DIR/agent.sock" \
    ansible-playbook -i "$(qemu_inventory)" "$@"
}

# Run one example against a target: example_run <example> <qemu>.
# (Cloud targets left with the DO harness; amd64 example runs happen
# manually against a sandbox droplet — see examples/README.md.)
example_run() {
  _example_playbook="$MISE_CONFIG_ROOT/examples/$1/site.yml"
  (
    export ANSIBLE_COLLECTIONS_PATH="$MISE_CONFIG_ROOT/.generated/collections"
    case "$2" in
      qemu) qemu_ansible_playbook "$_example_playbook" ;;
      *)
        echo "Unknown example target '$2' (expected qemu)." >&2
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
      # A reachable VM whose cloud-init landed in the error state will
      # never turn done: fail now instead of spinning out the deadline.
      if "$_wait_probe" cloud-init status 2>/dev/null | grep -q 'status: error'; then
        echo "cloud-init finished in the error state; inspect the console log." >&2
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
  echo "cloud-init is done; the VM is ready."
}

# Test one example against a target: example_test <name> <do|qemu>.
# The examples' contract: the second run is a full no-op. Second-run output
# goes to a log so a clean pass stays quiet; recap lines are the only place
# ansible prints "changed=N", so grepping the log for a non-zero count is
# exact.
example_test() {
  _test_name="$1"
  _test_target="$2"

  echo "==> $_test_name ($_test_target): first run"
  example_run "$_test_name" "$_test_target"

  echo "==> $_test_name ($_test_target): second run (idempotency contract: changed=0)"
  _second_log="$ANSIBLE_LOCAL_TEMP/example-test-$_test_name.log"
  if ! example_run "$_test_name" "$_test_target" > "$_second_log" 2>&1; then
    cat "$_second_log"
    echo "FAIL $_test_name: second run failed." >&2
    exit 1
  fi
  if grep -qE 'changed=[1-9]' "$_second_log"; then
    grep -A9 "PLAY RECAP" "$_second_log" || cat "$_second_log"
    echo "FAIL $_test_name: second run reported changes." >&2
    exit 1
  fi
  grep -hA3 "PLAY RECAP" "$_second_log" | sed "s/^/    /"
}

# Test every example against a target: example_test_all <do|qemu>. Coverage
# comes from globbing examples/ — a missing per-example task wrapper can
# never silently drop an example from the suite; it only earns a warning.
example_test_all() {
  _test_all_target="$1"
  _test_all_skipped=""

  for _example_dir in "$MISE_CONFIG_ROOT/examples"/*/; do
    _example_name="$(basename "$_example_dir")"
    [ -f "$_example_dir/site.yml" ] || continue

    if [ "$_test_all_target" = "qemu" ] \
      && [ ! -x "$MISE_CONFIG_ROOT/mise-tasks/$_test_all_target/test/$_example_name" ]; then
      echo "WARN examples/$_example_name has no mise-tasks/$_test_all_target/test/$_example_name wrapper (still tested by this suite)." >&2
    fi

    if [ "$_example_name" = "tailscale" ] && [ -z "${TAILSCALE_AUTHKEY:-}" ]; then
      echo "SKIP tailscale: TAILSCALE_AUTHKEY is not set. (Joining also leaves a node"
      echo "in the tailnet admin console unless the auth key is ephemeral.)"
      _test_all_skipped="$_test_all_skipped tailscale"
      continue
    fi

    example_test "$_example_name" "$_test_all_target"
  done

  echo "All examples passed twice on $_test_all_target.${_test_all_skipped:+ Skipped:$_test_all_skipped.}"
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
    -o IdentityAgent="$QEMU_KEYS_DIR/agent.sock" \
    -o ConnectTimeout=10 \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=4 \
    -i "$_qemu_ssh_identity" \
    -p "$QEMU_SSH_PORT" \
    "$_qemu_ssh_user@127.0.0.1" "$@"
}

# Assert a captured ansible-playbook log reported changed=0 (the
# idempotency contract), printing its recap: assert_changed_zero <log> <label>
assert_changed_zero() {
  if grep -qE 'changed=[1-9]' "$1"; then
    grep -A9 "PLAY RECAP" "$1" || cat "$1"
    echo "FAIL $2: reported changes; expected changed=0." >&2
    exit 1
  fi
  grep -hA3 "PLAY RECAP" "$1" | sed 's/^/    /'
}

# Assert a captured report-access log shows an access surface of exactly
# the two baseline doors — ssh-key doors ansible+sysadmin only, no
# unlocked-password doors, no unexpected keys: assert_two_doors <log>
assert_two_doors() {
  _doors="$(awk '/doors, ssh keys/{f=1;next} /doors, unlocked passwords/{f=0} f' "$1" \
    | tr -d '",' | awk '{print $1}' | grep -v '^(none)$' | sort | paste -s -d' ' -)"
  if [ "$_doors" != "ansible sysadmin" ]; then
    echo "FAIL: expected exactly the two baseline doors, saw: ${_doors:-none}" >&2
    exit 1
  fi
  if ! awk '/doors, unlocked passwords/{f=1;next} /privileged group members/{f=0} f' "$1" | grep -q '(none)'; then
    echo "FAIL: expected no unlocked-password doors." >&2
    exit 1
  fi
  if ! grep -q 'ansible: 0' "$1" || ! grep -q 'sysadmin: 0' "$1"; then
    echo "FAIL: unexpected keys on a baseline account." >&2
    exit 1
  fi
  echo "Access surface: exactly ansible + sysadmin."
}

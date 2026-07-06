# Shared helpers, sourced by every task script (bash; the sourcing task
# sets `set -euo pipefail`). Deliberately NOT executable: mise only
# detects executable files as tasks, so this stays a library.
# (Corollary: new task scripts MUST be chmod +x or mise silently
# ignores them; the vendored qemu-vm.sh relies on the same rule to
# stay out of the task list.)

# === task preamble ======================================================

# Ansible does not create a custom local tmp dir on its own; every task
# that runs ansible calls this first (ANSIBLE_LOCAL_TEMP is pinned
# under .generated/ in mise.toml).
prepare_ansible_temp() {
  mkdir -p "$ANSIBLE_LOCAL_TEMP"
}

# === the VM harness =====================================================

# The vendored VM harness (upstream: cur8s/qemu; refresh procedure in
# its header). Its QVM_* interface is fed straight from the mise env;
# callers may override per invocation (scenario builds set QVM_NAME
# and QVM_USER_DATA). It lives inside mise-tasks/ because this wrapper
# is its only consumer — and stays non-executable so mise never
# detects it as a task; bash matches its shebang.
qvm() {
  bash "$MISE_CONFIG_ROOT/mise-tasks/vendor/qemu-vm.sh" "$@"
}

# === lab credentials (RFC-004) ==========================================

# Make the lab's throwaway credentials available: generate missing
# keypairs, ensure the lab's promptless ssh-agent is up, and export the
# env vars the playbooks and render script read. Ephemeral lab
# credentials open nothing but a disposable VM on a loopback port, live
# git-ignored, and die with `clean`. Private keys sit next to their
# .pub, so every existing `-i <pubfile>` mechanic works without the
# 1Password agent: ssh uses the adjacent private file. The DigitalOcean
# integration never calls this and keeps the vault-held keys.
export_lab_credentials() {
  local key
  for key in ubuntu-bootstrap ubuntu-ansible ubuntu-sysadmin; do
    if [[ ! -f "$QEMU_KEYS_DIR/$key" ]]; then
      mkdir -p "$QEMU_KEYS_DIR"
      ssh-keygen -q -t ed25519 -N '' -C "qemu-lab-$key" -f "$QEMU_KEYS_DIR/$key"
      # 0600 like the vault-extracted pubs: ssh tries identity files as
      # private keys first and refuses world-readable ones.
      chmod 600 "$QEMU_KEYS_DIR/$key.pub"
    fi
  done

  # A dedicated, promptless ssh-agent holds the lab keys, so every
  # pub-as-identity mechanic (`-i <file>.pub`) works exactly as it does
  # against 1Password — the lab merely substitutes its own agent.
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

  export BOOTSTRAP_PUB_KEY="$QEMU_KEYS_DIR/ubuntu-bootstrap.pub"
  export ANSIBLE_PUB_KEY="$QEMU_KEYS_DIR/ubuntu-ansible.pub"
  export SYSADMIN_PUB_KEY="$QEMU_KEYS_DIR/ubuntu-sysadmin.pub"
  export CLOUD_INIT_FILE="$QEMU_CLOUD_INIT_FILE"
}

# === ansible against the lab VM =========================================

# Write the lab inventory (regenerated on use so QVM_* env stays
# authoritative) and print its path. A named alias is load-bearing: an
# inventory host literally named 127.0.0.1 is treated as a localhost
# alias, so `hosts: localhost` plays and `delegate_to: localhost` tasks
# would SSH into the VM instead of running locally.
write_qemu_inventory() {
  printf '%s ansible_host=127.0.0.1 ansible_port=%s\n' "$QVM_NAME" "$QVM_SSH_PORT" \
    > "$QVM_DIR/inventory"
  printf '%s' "$QVM_DIR/inventory"
}

# Run a playbook against the local QEMU VM: qemu_ansible_playbook <playbook> [args...]
# Exports the lab credentials first, so playbooks that read *_PUB_KEY
# resolve the throwaway lab keys, never the vault's.
qemu_ansible_playbook() {
  if [[ ! -d $QVM_DIR ]]; then
    echo "No local QEMU VM exists (mise run up)." >&2
    return 1
  fi
  export_lab_credentials
  # IdentityAgent is pinned explicitly: 1Password's ~/.ssh/config sets a
  # global IdentityAgent, which overrides SSH_AUTH_SOCK — without the pin,
  # lab traffic would consult the 1Password agent and prompt. The
  # VALIDATE_SSH_IDENTITY_AGENT export makes the collection's validation
  # probe pin the same lab agent (by default the probe follows the user's
  # ssh config, which is right everywhere except this lab).
  VALIDATE_SSH_IDENTITY_AGENT="$QEMU_KEYS_DIR/agent.sock" \
    ANSIBLE_SSH_COMMON_ARGS="-o UserKnownHostsFile=$QVM_DIR/known_hosts -o StrictHostKeyChecking=accept-new -o IdentityAgent=$QEMU_KEYS_DIR/agent.sock" \
    ansible-playbook -i "$(write_qemu_inventory)" "$@"
}

# SSH to the local QEMU VM: qemu_ssh <user> <identity-file> [command...]
# Deliberately parallel to `qvm ssh`, with one divergence: IdentityAgent
# points at the lab agent (pub-as-identity needs it) where the vendored
# script pins IdentityAgent=none. Each fresh VM presents new host keys
# on the same forwarded port, so the known_hosts file lives in the VM
# state dir and dies with it.
qemu_ssh() {
  local user="$1" identity="$2"
  shift 2
  ssh \
    -o UserKnownHostsFile="$QVM_DIR/known_hosts" \
    -o StrictHostKeyChecking=accept-new \
    -o IdentitiesOnly=yes \
    -o IdentityAgent="$QEMU_KEYS_DIR/agent.sock" \
    -o ConnectTimeout=10 \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=4 \
    -i "$identity" \
    -p "$QVM_SSH_PORT" \
    "$user@127.0.0.1" "$@"
}

# === the example suite ==================================================

# Run one example against a target: run_example <example> <qemu>.
# (Cloud targets live with the DO harness in the operator's sandbox
# repo; amd64 example runs happen manually against a sandbox droplet —
# see examples/README.md.)
run_example() {
  local playbook="$MISE_CONFIG_ROOT/examples/$1/site.yml" target="$2"
  (
    export ANSIBLE_COLLECTIONS_PATH="$MISE_CONFIG_ROOT/.generated/collections"
    case "$target" in
      qemu) qemu_ansible_playbook "$playbook" ;;
      *)
        echo "Unknown example target '$target' (expected qemu)." >&2
        exit 1
        ;;
    esac
  )
}

# Test one example against a target: test_example <name> <qemu>.
# The examples' contract: the second run is a full no-op. Second-run
# output goes to a log so a clean pass stays quiet; recap lines are the
# only place ansible prints "changed=N", so grepping the log for a
# non-zero count is exact.
test_example() {
  local name="$1" target="$2"

  echo "==> $name ($target): first run"
  run_example "$name" "$target"

  echo "==> $name ($target): second run (idempotency contract: changed=0)"
  local second_log="$ANSIBLE_LOCAL_TEMP/example-test-$name.log"
  if ! run_example "$name" "$target" > "$second_log" 2>&1; then
    cat "$second_log"
    echo "FAIL $name: second run failed." >&2
    exit 1
  fi
  if grep -qE 'changed=[1-9]' "$second_log"; then
    grep -A9 "PLAY RECAP" "$second_log" || cat "$second_log"
    echo "FAIL $name: second run reported changes." >&2
    exit 1
  fi
  grep -hA3 "PLAY RECAP" "$second_log" | sed "s/^/    /"
}

# Test every example against a target: test_all_examples <qemu>.
# Coverage comes from globbing examples/ — a missing per-example task
# wrapper can never silently drop an example from the suite; it only
# earns a warning.
test_all_examples() {
  local target="$1" skipped="" example_dir name

  for example_dir in "$MISE_CONFIG_ROOT/examples"/*/; do
    name="$(basename "$example_dir")"
    [[ -f $example_dir/site.yml ]] || continue

    # The per-example wrappers live at mise-tasks/test/<example>.
    if [[ $target == qemu && ! -x "$MISE_CONFIG_ROOT/mise-tasks/test/$name" ]]; then
      echo "WARN examples/$name has no mise-tasks/test/$name wrapper (still tested by this suite)." >&2
    fi

    if [[ $name == tailscale && -z ${TAILSCALE_AUTHKEY:-} ]]; then
      echo "SKIP tailscale: TAILSCALE_AUTHKEY is not set. (Joining also leaves a node"
      echo "in the tailnet admin console unless the auth key is ephemeral.)"
      skipped="$skipped tailscale"
      continue
    fi

    test_example "$name" "$target"
  done

  echo "All examples passed twice on $target.${skipped:+ Skipped:$skipped.}"
}

# === assertions =========================================================

# Assert a captured ansible-playbook log reported changed=0 (the
# idempotency contract), printing its recap: assert_changed_zero <log> <label>
assert_changed_zero() {
  local log="$1" label="$2"
  if grep -qE 'changed=[1-9]' "$log"; then
    grep -A9 "PLAY RECAP" "$log" || cat "$log"
    echo "FAIL $label: reported changes; expected changed=0." >&2
    exit 1
  fi
  grep -hA3 "PLAY RECAP" "$log" | sed 's/^/    /'
}

# Assert a captured report-access log shows an access surface of exactly
# the two baseline doors — ssh-key doors ansible+sysadmin only, no
# unlocked-password doors, no unexpected keys: assert_two_doors <log>
assert_two_doors() {
  local log="$1" doors unlocked
  # grep -v exits 1 when every door filters away (a healthy "(none)"
  # report), and pipefail would turn that into a false failure — hence
  # the || true on the capture.
  doors="$(awk '/doors, ssh keys/{f=1;next} /doors, unlocked passwords/{f=0} f' "$log" \
    | tr -d '",' | awk '{print $1}' | grep -v '^(none)$' | sort | paste -s -d' ' - || true)"
  if [[ $doors != "ansible sysadmin" ]]; then
    echo "FAIL: expected exactly the two baseline doors, saw: ${doors:-none}" >&2
    exit 1
  fi
  # Captured, then tested in bash — not piped to grep -q: under pipefail
  # an early-exiting grep can fail the very pipeline it reads (SIGPIPE).
  unlocked="$(awk '/doors, unlocked passwords/{f=1;next} /privileged group members/{f=0} f' "$log")"
  if [[ $unlocked != *'(none)'* ]]; then
    echo "FAIL: expected no unlocked-password doors." >&2
    exit 1
  fi
  if ! grep -q 'ansible: 0' "$log" || ! grep -q 'sysadmin: 0' "$log"; then
    echo "FAIL: unexpected keys on a baseline account." >&2
    exit 1
  fi
  echo "Access surface: exactly ansible + sysadmin."
}

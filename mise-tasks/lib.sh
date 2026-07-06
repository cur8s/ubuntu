# Shared helpers, sourced by every task script (bash; the sourcing task
# sets `set -euo pipefail`). Deliberately NOT executable: mise only
# detects executable files as tasks, so this stays a library.
# (Corollary: new task scripts MUST be chmod +x or mise silently
# ignores them; the vendored qemu-vm.sh relies on the same rule to
# stay out of the task list.)
# Admission rule: nothing lives here with fewer than two calling
# tasks — a single-caller function belongs in its calling task.

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

# === test credentials (RFC-004) =========================================

# The custody shim ships with the collection, so a consumer lab's
# credential mechanics always match the collection version it
# installed (RFC-004 travels with its implementation; the agent
# rationale lives in the shim's header). Sourcing defines
# activate_test_credentials; tasks call it before anything that SSHes.
# The DigitalOcean integration never calls it and keeps the
# vault-held keys.
. "$MISE_CONFIG_ROOT/collection/scripts/activate-test-credentials.sh"

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
# Activates the test credentials first, so playbooks that read
# *_PUB_KEY resolve the throwaway test keys, never the vault's.
qemu_ansible_playbook() {
  if [[ ! -d $QVM_DIR ]]; then
    echo "No local QEMU VM exists (mise run up)." >&2
    return 1
  fi
  activate_test_credentials
  # Ansible does not create a custom local tmp dir on its own
  # (ANSIBLE_LOCAL_TEMP is pinned under .generated/ in mise.toml).
  mkdir -p "$ANSIBLE_LOCAL_TEMP"
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


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

# === the collection's lab library =======================================

# The lab tooling ships with the collection, so a consumer lab's
# mechanics always match the collection version it installed (RFC-004
# and the connection contract travel with their implementation; the
# rationale lives in the scripts' headers). One source line defines
# run_lab_playbook and, via its sibling shim,
# activate_test_credentials; tasks call them directly. The
# DigitalOcean integration never uses these and keeps the vault-held
# keys.
. "$MISE_CONFIG_ROOT/collection/scripts/run-lab-playbook.sh"

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
      qemu) run_lab_playbook "$playbook" ;;
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


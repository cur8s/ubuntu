# example-suite.sh — the test namespace's example suite: run one
# example, or test one against the idempotency contract. Sourced by
# test/docker, test/zot, test/tailscale, and test/all; no other
# namespace uses these. Sources everything it needs itself, so a test
# task needs only this file. Deliberately NOT executable: mise only
# detects executable files as tasks, so this stays a library.

. "$MISE_CONFIG_ROOT/collection/scripts/run-lab-playbook.sh"

# Run one example against a target: run_example <example> <qemu>.
# (Cloud targets live with the DO harness in the operator's sandbox
# repo; amd64 example runs happen manually against a sandbox droplet —
# see examples/README.md.)
run_example() {
  local playbook="$MISE_CONFIG_ROOT/examples/$1/site.yml" target="$2"
  # Examples resolve cur8s.ubuntu from the working tree through a dev
  # link, refreshed on every run (ln -sfn is idempotent).
  mkdir -p "$MISE_CONFIG_ROOT/.generated/collections/ansible_collections/cur8s"
  ln -sfn ../../../../collection \
    "$MISE_CONFIG_ROOT/.generated/collections/ansible_collections/cur8s/ubuntu"
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

# suite-asserts.sh — shared helpers for the test suites (the
# namespace-lib admission rule: a helper earns a shared file only once
# it has two calling tasks, and it lives inside the namespace that
# calls it). Deliberately not executable: it defines functions and must
# run in the caller's shell.

# Assert a captured ansible-playbook log reported changed=0 (the
# idempotency contract), printing its recap: assert_changed_zero <log> <label>
assert_changed_zero() {
  local log="$1" label="$2"
  # A log with no recap must fail loudly here: without this guard the
  # changed= scan below passes vacuously and the narration pipeline
  # then kills the caller under pipefail with no evidence at all.
  if ! grep -q 'PLAY RECAP' "$log"; then
    cat "$log"
    echo "FAIL $label: no PLAY RECAP in the log." >&2
    exit 1
  fi
  if grep -qE 'changed=[1-9]' "$log"; then
    grep -A9 "PLAY RECAP" "$log" || cat "$log"
    echo "FAIL $label: reported changes; expected changed=0." >&2
    exit 1
  fi
  grep -A3 "PLAY RECAP" "$log" | sed 's/^/    /'
}

# Assert a captured report-access log shows an access surface of exactly
# the two baseline doors — ssh-key doors ansible+sysadmin only, no
# unlocked-password doors, no unexpected keys: assert_two_doors <log> <label>
assert_two_doors() {
  local log="$1" label="${2:-report}" doors unlocked
  # grep -v exits 1 when every door filters away (a healthy "(none)"
  # report), and pipefail would turn that into a false failure — hence
  # the || true on the capture.
  doors="$(awk '/doors, ssh keys/{f=1;next} /doors, unlocked passwords/{f=0} f' "$log" \
    | tr -d '",' | awk '{print $1}' | grep -v '^(none)$' | sort | paste -s -d' ' - || true)"
  if [[ $doors != "ansible sysadmin" ]]; then
    cat "$log"
    echo "FAIL $label: expected exactly the two baseline doors, saw: ${doors:-none}" >&2
    exit 1
  fi
  # Captured, then tested in bash — not piped to grep -q: under pipefail
  # an early-exiting grep can fail the very pipeline it reads (SIGPIPE).
  unlocked="$(awk '/doors, unlocked passwords/{f=1;next} /privileged group members/{f=0} f' "$log")"
  if [[ $unlocked != *'(none)'* ]]; then
    cat "$log"
    echo "FAIL $label: expected no unlocked-password doors." >&2
    exit 1
  fi
  if ! grep -q 'ansible: 0' "$log" || ! grep -q 'sysadmin: 0' "$log"; then
    cat "$log"
    echo "FAIL $label: unexpected keys on a baseline account." >&2
    exit 1
  fi
  echo "Access surface: exactly ansible + sysadmin."
}

# Ensure the conformant lab is the occupant and running; rebuild the
# slot if anything else (or nothing) sits in it. The harness's name row
# is read from the built VM's own seed, so it names the actual occupant.
require_conformant_lab() {
  local harness occupant vm_state
  harness="$(bash "$MISE_CONFIG_ROOT/mise-tasks/vendor/qemu-vm.sh" status)"
  occupant="$(awk '$1 == "name" {print $2}' <<<"$harness")"
  vm_state="$(awk '$1 == "vm" {print $2}' <<<"$harness")"
  if [ "$occupant" != "ubuntu-qemu-lab" ] || [ "$vm_state" != "running" ]; then
    if [ -e "$QVM_DIR" ]; then
      MISE_YES=1 mise run vm:destroy
    fi
    mise run up
  fi
}

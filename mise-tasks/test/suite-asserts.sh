# suite-asserts.sh — shared assertions for the test suites. Sourced by
# test/adoption and test/rotation (the namespace-lib admission rule:
# a helper earns a shared file only once it has two calling tasks, and
# it lives inside the namespace that calls it). Deliberately not
# executable: it defines functions and must run in the caller's shell.

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

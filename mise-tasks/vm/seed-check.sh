# seed-check.sh — refuse to build from a seed that does not parse.
# A broken seed boots a VM with no doors: the failure surfaces minutes
# later as a wait timeout instead of an error naming the file (the
# 2026-07-06 unadoptable-seed YAML bug). Parsing borrows the Python
# that ansible-core already carries — PyYAML is its hard dependency —
# so the check adds no workstation requirement; plain python3 is the
# fallback if ansible's version banner ever changes shape.
# Sourced by the three vm build tasks (the namespace-lib admission
# rule: multiple callers, living inside the namespace that calls it).

# assert_seed_parses <file>
assert_seed_parses() {
  local seed="$1" py
  # The banner holds several parenthesized groups; the interpreter path
  # is the one that starts with a slash, e.g.
  #   python version = 3.14.6 (main, ...) [Clang ...] (/opt/.../python)
  # The || true keeps a missing/failing ansible-playbook from killing
  # the caller under pipefail before the python3 fallback can engage.
  py="$(ansible-playbook --version 2>/dev/null | sed -n 's/.*python version = .*(\(\/[^)]*\)).*/\1/p' || true)"
  py="${py:-python3}"
  # cloud-init silently ignores user-data without this exact first line
  # — the same doorless-VM outcome a parse failure produces.
  if [ "$(head -n 1 "$seed")" != "#cloud-config" ]; then
    echo "Refusing to build: $seed does not start with '#cloud-config' (cloud-init would silently ignore it)." >&2
    exit 1
  fi
  if ! "$py" -c 'import yaml' 2>/dev/null; then
    echo "Refusing to build: $py cannot import PyYAML (ansible-core normally bundles it)." >&2
    exit 1
  fi
  if ! "$py" -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1]))' "$seed"; then
    echo "Refusing to build: $seed is not valid YAML (parse error above; parser: $py)." >&2
    exit 1
  fi
}

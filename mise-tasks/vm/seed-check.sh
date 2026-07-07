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
  py="$(ansible-playbook --version 2>/dev/null | sed -n 's/.*python version = .*(\(\/[^)]*\)).*/\1/p')"
  if ! "${py:-python3}" -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1]))' "$seed"; then
    echo "Refusing to build: $seed is not valid YAML (parse error above)." >&2
    exit 1
  fi
}

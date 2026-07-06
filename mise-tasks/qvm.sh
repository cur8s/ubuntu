# qvm.sh — the vendored VM harness's one wrapper (upstream: cur8s/qemu;
# refresh procedure in the vendored file's header). Its QVM_* interface
# is fed straight from the mise env; callers may override per
# invocation (scenario builds set QVM_NAME and QVM_USER_DATA). This is
# deliberately the only place the invocation is written: the vendored
# file lives inside mise-tasks/ and stays non-executable so mise never
# detects it as a task, which means it MUST be run via bash (matching
# its shebang) — a rule encoded once, here. This wrapper file is
# non-executable for the same reason: mise only detects executable
# files as tasks. (Corollary: new task scripts MUST be chmod +x or
# mise silently ignores them.)
qvm() {
  bash "$MISE_CONFIG_ROOT/mise-tasks/vendor/qemu-vm.sh" "$@"
}

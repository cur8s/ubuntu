# TODO — Implement RFC-001 (Baseline Ubuntu)

Remaining work to fully implement `docs/rfcs/RFC-001 Baseline Goals and Architecture.md`.
Update as items land. `[x]` done · `[~]` in progress · `[ ]` not started.

## Done (foundation, verified end-to-end)
- [x] RFC-001 written & committed; N-1 LTS rationale folded into §3 (no longer depends on `archive/`).
- [x] Model B cloud-init (`playbooks/cloud-init/render.sh`): creates `ansible` + `sysadmin`, per-user sudoers byte-matching the role, sshd drop-in embedded from `roles/ssh/files/10-ubuntu-baseline.conf`, native `package_update`/`package_upgrade` (dist-upgrade), unconditional first-boot reboot (kernel + smoke test), ASCII-only guard.
- [x] `roles/ssh` (drop-in via shared file), `roles/users` (`ansible` + `sysadmin`).
- [x] `mise.toml`: `cloud-init:render`, `vm:create --user-data-file`, `ssh:sysadmin`, `SYSADMIN_PUB_KEY`, `key:extract` → `op://devops/ubuntu-sysadmin`.
- [x] 1Password item renamed `ubuntu-admin` → `ubuntu-sysadmin`.
- [x] **Verified:** cloud-init brings up both users; `mise run vm:converge` is a no-op (`changed=0`) — the byte-identity / first-converge-no-op design holds.

## Behavioral floor roles (converge-only; RFC-001 §5, §7)
- [x] **unattended_upgrades** — role created (`roles/unattended_upgrades`) + wired into `converge.yml`. Security-only, `Automatic-Reboot false`. **Verified 2026-07-02:** converge applies it (`changed=1`, the `52-baseline` drop-in), 2nd converge is a no-op (`changed=0`), full `--check --diff` is clean, and drift-injection passes — deleted the drop-in on the droplet, `--check --diff` flagged exactly that task with the correct file diff (`changed=1 failed=0`), converge restored it (`changed=1`).
- [x] **time sync** — `roles/time_sync`: asserts the 24.04 default (`systemd-timesyncd` package present, service enabled/active, `timedatectl` reports NTP-synchronized; probe runs under `--check` so the assert stays trustworthy). **Verified 2026-07-02:** all tasks `ok` on first converge, no-op on 2nd, check-mode-clean.
- [x] **audit / log capture** — **DECIDED 2026-07-02: persistent `journald` only; no `auditd` in the floor.** Rationale (see `roles/journald/README.md`): RFC-001 §9 scopes the floor to role-level attribution (per-person "who" is the access layer's job); auditd rulesets need curation, are noisy/costly on container hosts (k3s), and fail the floor test — a compliance layer can add auditd later, unfought. Role `roles/journald` pins `Storage=persistent` via drop-in, repairs a deleted `/var/log/journal` (`journalctl --flush`), asserts journal files on disk; rsyslog and size defaults left alone. **Verified 2026-07-02:** first converge applies it (`changed=3`), 2nd converge is a no-op (`changed=0`), `--check --diff` clean. Drop-in-deletion drift is mechanically identical to the proven unattended_upgrades test (copy module), so not re-run. Deleted-journal-dir drift test ran with operator approval: journald **self-heals** within seconds of the next log write ("Journal file has been deleted, rotating"), so the role's flush repair branch was unreachable — removed; the role now probes + asserts only (see `roles/journald/README.md`, including the recreated-dir attribute caveat and its `systemd-tmpfiles --create` remediation). Session side note: back-to-back converge/check runs trip the UCG IPS cooldown (§12) — space them out.
- [ ] **bootstrap retirement** (RFC-001 §8) — gated converge role/task. Takes provider-bootstrap-username as input; runs ONLY after the `ansible`+`sysadmin` validations pass; strips its `authorized_keys`, drops its cloud-init sudoers, and `usermod -L` locks it (does NOT delete). Add per-environment on/off toggle (dev skips, prod enables). Design settled; test carefully (lockout risk). Note: decided to keep this at converge, NOT cloud-init (keeps root as a debug/break-glass path during first-boot bring-up).

## Validation & testing (RFC-001 §11, §12)
- [ ] **Reboot-validation acceptance test** — opt-in play (NEVER routine converge): reboot → wait → re-verify `ansible`+`sysadmin` SSH+sudo → confirm floor services healthy. In the collection as an acceptance gate + wired into the `mise` test harness.
- [x] Confirm every role is **check-mode-clean** (`--check --diff` trustworthy, no false "changed"). **Verified 2026-07-02** for `users`/`ssh`/`unattended_upgrades`/`time_sync`: fixed `ssh` role (its `sshd -T` probe was skipped under `--check`, breaking the assert; now `check_mode: false`), full `--check --diff` runs `changed=0 failed=0`. Discipline for new roles: read-only probes get `changed_when: false` + `check_mode: false`.
- [ ] Honor §12: run SSH-heavy ops (reboot validation, first converge) from CI/tailnet, not bursted from behind the UCG IPS.

## Cleanup & structure
- [ ] Retire/remove legacy **`playbooks/initialize.yml`** (superseded by cloud-init Model B). Decide: delete vs. keep as a non-cloud-init fallback.
- [ ] **Delete `archive/`** once the rebuild is done (historical; nothing in the active tree references it).
- [ ] RFC-001 §14 open item: enumerate the full **conventions contract** (stable paths, Ansible facts/vars layers may rely on) as roles solidify.

## Collection / packaging (RFC-001 §3, §10)
- [ ] Make this a proper **`baseline.ubuntu` Ansible collection**: `galaxy.yml`, namespace, **semver tiered to the Ubuntu LTS**, N-1 LTS support policy.
- [ ] Prove the **three-tier composition**: a use-case collection (e.g. `baseline.k3s`) depends on `baseline.ubuntu` and its converge re-asserts the floor.

## Out of scope for THIS repo (separate work)
- `baseline.tailscale` collection (opt-in access layer; the canonical dogfood consumer) — its own repo.
- Optional **Multipass local-dev loop** (`vm:init-local`) for gateway-free iteration on the same render.
- Bare-metal **`autoinstall`** wrapper (nest the cloud-config under `autoinstall.user-data`, seed via NoCloud).

## Key files
- `docs/rfcs/RFC-001 Baseline Goals and Architecture.md` — goals & architecture (source of truth)
- `docs/rfcs/RFC-000 SSH Key Strategy.md` — SSH key strategy
- `docs/notes/ucg-fibre-ips-ssh-blocking.md` — the IPS incident that drove the cloud-init design
- `playbooks/cloud-init/render.sh` — cloud-init generator (Model B)
- `playbooks/converge.yml` — converge entrypoint (add behavioral roles here)

# TODO — cur8s.ubuntu

Update as items land. `[x]` done · `[~]` in progress · `[ ]` not started.

> Note: entries dated before 2026-07-03 cite sections of the retired RFC set
> ("RFC-001 §N" etc.) and use retired vocabulary: "floor" is now "baseline"
> (the invariant tier), and the collection namespace moved from `baseline` to
> `cur8s` (`baseline.ubuntu` → `cur8s.ubuntu`). Historical entries are left as
> written.

## Done (foundation, verified end-to-end)
- [x] RFC-001 written & committed; N-1 LTS rationale folded into §3 (no longer depends on `archive/`).
- [x] Model B cloud-init (`playbooks/cloud-init/render.sh`): creates `ansible` + `sysadmin`, per-user sudoers byte-matching the role, sshd drop-in embedded from `roles/ssh/files/10-ubuntu-baseline.conf`, native `package_update`/`package_upgrade` (dist-upgrade), unconditional first-boot reboot (kernel + smoke test), ASCII-only guard.
- [x] `roles/ssh` (drop-in via shared file), `roles/users` (`ansible` + `sysadmin`).
- [x] `mise.toml`: `cloud-init:render`, `vm:create --user-data-file`, `ssh:sysadmin`, `SYSADMIN_PUB_KEY`, `key:extract` → `op://devops/ubuntu-sysadmin`.
- [x] 1Password item renamed `ubuntu-admin` → `ubuntu-sysadmin`.
- [x] **Verified:** cloud-init brings up both users; `mise run vm:converge` is a no-op (`changed=0`) — the byte-identity / first-converge-no-op design holds.

## Behavioral baseline roles (converge-only; RFC-002, RFC-003)
- [x] **unattended_upgrades** — role created (`roles/unattended_upgrades`) + wired into `converge.yml`. Security-only, `Automatic-Reboot false`. **Verified 2026-07-02:** converge applies it (`changed=1`, the `52-baseline` drop-in), 2nd converge is a no-op (`changed=0`), full `--check --diff` is clean, and drift-injection passes — deleted the drop-in on the droplet, `--check --diff` flagged exactly that task with the correct file diff (`changed=1 failed=0`), converge restored it (`changed=1`).
- [x] **time sync** — **DECIDED 2026-07-02 (reversal): dropped from the floor; role deleted.** timesyncd ships installed/enabled/syncing on every Ubuntu cloud image and providers supply sources; pinning the mechanism (`apt: systemd-timesyncd present`) would uninstall chrony if a layer ever wanted it — the floor fighting a layer. RFC-001 §7 amended (moved to the "explicitly not in the floor" list). Revisit with a mechanism-agnostic `timedatectl` assert on first real clock incident. (The deleted role was verified working first — see commit `3a7a9e2`.)
- [x] **audit / log capture** — **DECIDED 2026-07-02: persistent `journald` only; no `auditd` in the floor.** Rationale (see `roles/journald/README.md`): RFC-001 §9 scopes the floor to role-level attribution (per-person "who" is the access layer's job); auditd rulesets need curation, are noisy/costly on container hosts (k3s), and fail the floor test — a compliance layer can add auditd later, unfought. Role `roles/journald` pins exactly one setting — `Storage=persistent` via drop-in (stock `auto` only persists if `/var/log/journal` happens to exist) — plus restart-on-change and service-active; rsyslog and size defaults left alone. **Simplified 2026-07-02** per keep-the-floor-close-to-default: no verification/repair tasks. The drift experiment justified it — `rm -rf /var/log/journal` with operator approval showed journald **self-heals** on its next log write ("Journal file has been deleted, rotating"), so a converge-time existence probe can never observe the broken state (converge itself generates journal writes). Caveat + remediation for the recreated dir's lost setgid/ACL attrs documented in `roles/journald/README.md`. **Verified 2026-07-02** (pre-simplification, commit `03c2c98`): first converge `changed=3`, 2nd no-op, `--check --diff` clean; re-verified after simplification. Session side note: back-to-back converge/check runs trip the UCG IPS cooldown (§12) — space them out.
- [x] **bootstrap retirement** (RFC-001 §8) — `roles/bootstrap_retirement`, invoked from converge `post_tasks` AFTER the `ansible`+`sysadmin` validations, gated on `BOOTSTRAP_RETIRE=true` + `BOOTSTRAP_USER=<name>` (off by default: dev keeps the provider door, prod retires it). Strips `authorized_keys`, removes `/etc/sudoers.d/90-cloud-init-users` (baseline accounts use their own per-user files — verified the combined file holds only a redundant root rule), locks the password (never deletes). `mise run vm:retire-bootstrap` (with confirm) for the lab. **Verified 2026-07-02 on the droplet:** root SSH worked pre-retirement (positive control) → retirement converge `changed=3` → root SSH `Permission denied (publickey)` → re-run `changed=0` (idempotent) → toggle-off converge skips it. Ran after `vm:validate-reboot` passed, per the safety ordering.

## Validation & testing (RFC-007)
- [x] **Reboot-validation acceptance test** — `playbooks/validate_reboot.yml` (underscore: collection playbook FQCNs forbid hyphens) + `mise run vm:validate-reboot`: reboot (IPS-aware `post_reboot_delay`) → re-verify `ansible`+`sysadmin` SSH+sudo → floor units active → previous-boot journal readable (proves the journald pin across reboots). **Verified 2026-07-02** on the droplet.
- [x] Confirm every role is **check-mode-clean** (`--check --diff` trustworthy, no false "changed"). **Verified 2026-07-02** for `users`/`ssh`/`unattended_upgrades`/`journald`: fixed `ssh` role (its `sshd -T` probe was skipped under `--check`, breaking the assert; now `check_mode: false`), full `--check --diff` runs `changed=0 failed=0`. Discipline for new roles: read-only probes get `changed_when: false` + `check_mode: false`.
- [x] Honor §12 (SSH bursts vs. the UCG IPS) — resolved differently: the UCG IPS was disabled 2026-07-03, and `mise.toml` gained `SSH_SPACING_SECONDS` (default `0`, honored by `vm:converge`/`vm:validate-reboot`/`vm:retire-bootstrap`) so spacing can be turned back on per-run if an IPS/rate-limiter ever returns. Running converges from CI/tailnet remains an environment-repo concern, not this collection's.

## Cleanup & structure
- [x] Retire/remove legacy **`playbooks/initialize.yml`** — deleted 2026-07-02 along with the `vm:init` mise task (Model B settled; git history is the fallback). README rewritten to the cloud-init flow.
- [x] **Delete `archive/`** — deleted 2026-07-02 (git history preserves it). Temporarily restored 2026-07-03 as a local untracked+gitignored reference copy while mining it for the RFC rewrite; safe to `rm -rf archive/` when done.
- [~] **Conventions contract** — now `docs/rfcs/RFC-009 Conventions Contract.md` (Status: Draft, first enumeration written 2026-07-03). Stays Draft until `cur8s.k3s` consumes it and proves it sufficient.

## Collection / packaging (RFC-001, RFC-008)
- [x] Make this a proper **`cur8s.ubuntu` Ansible collection** — **done 2026-07-03.** Distribution is git-only (no registry): `ansible-galaxy collection install git+https://github.com/cur8s/ubuntu.git`. Version `24.4.x`: major.minor mirror the target LTS (24.04), `x` counts releases; forever backward-compatible within the LTS era (the policy IS the contract), next LTS starts `26.4.0` and demotes this series to N-1. `main` is prod; version bumps get `v<version>` tags. **Verified:** clean tarball (build_ignore hygiene), install from git works, playbooks resolve by FQCN with roles resolving inside the collection (playbook renamed — FQCNs forbid hyphens). Namespace renamed `baseline` → `cur8s` later on 2026-07-03 (freeing "baseline" for the invariant tier); re-verified git install + `cur8s.ubuntu.converge`/`cur8s.ubuntu.validate_reboot` FQCN resolution.
- [ ] Prove the **three-tier composition**: a use-case collection (e.g. `cur8s.k3s`) depends on `cur8s.ubuntu` and its converge re-asserts the baseline.

## Out of scope for THIS repo (separate work)
- `cur8s.tailscale` collection (opt-in access layer; the canonical dogfood consumer) — its own repo.
- Optional **Multipass local-dev loop** (`vm:init-local`) for gateway-free iteration on the same render.
- Bare-metal **`autoinstall`** wrapper (nest the cloud-config under `autoinstall.user-data`, seed via NoCloud).

## Key files
- `docs/rfcs/` — the RFC series (start at RFC-000; architecture source of truth)
- `docs/operations/manual.md` — the operations manual
- `docs/notes/ucg-fibre-ips-ssh-blocking.md` — the IPS incident that drove the cloud-init design
- `playbooks/cloud-init/render.sh` — cloud-init generator (Model B)
- `playbooks/converge.yml` — converge entrypoint (add behavioral roles here)

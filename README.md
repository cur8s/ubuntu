# Ubuntu Ansible Collection

This repository is the `cur8s.ubuntu` Ansible collection: the baseline every
Ubuntu host gets, regardless of what runs on top. Everything needed to
develop, verify, release, and consume the collection is self-contained here:
the architecture and its rationale live in `docs/rfcs/` (start with RFC-000
and read in order); the how-to lives in `docs/operations/manual.md`; runnable
consumption examples live in `examples/`. The `mise` test harness may call
cloud providers and a secrets manager; the collection itself never does.

The steel thread:

1. Extract SSH public keys from 1Password.
2. Render cloud-init user-data from the same sources the roles use.
3. Create a DigitalOcean Ubuntu VM; cloud-init creates the `ansible` and
   `sysadmin` users, applies the sshd hardening drop-in, dist-upgrades, and
   reboots (RFC-005: Provisioning).
4. Converge over the `ansible` SSH path. The first converge is a no-op for
   everything cloud-init already applied; only the behavioral baseline controls
   do new work. Every subsequent converge is a no-op.

```sh
mise run key:extract
mise run key:upload
mise run vm:create   # renders cloud-init, creates the VM
mise run vm:converge
```

Acceptance test (opt-in; never part of routine converge):

```sh
mise run vm:validate-reboot   # reboot → re-verify access + baseline services
```

SSH shortcuts:

```sh
mise run ssh:root      # provider bootstrap path (until retirement)
mise run ssh:ansible
mise run ssh:sysadmin
```

## Ansible Shape

The baseline roles, applied by `playbooks/converge.yml`:

- `roles/users` — the fixed `ansible` (automation) and `sysadmin`
  (break-glass) accounts: creation, authorized keys, passwordless sudo.
- `roles/ssh` — the OpenSSH daemon policy drop-in (also embedded by
  cloud-init at first boot), validated with `sshd -t` and asserted with
  `sshd -T`.
- `roles/unattended_upgrades` — automatic security updates; reboots are never
  automatic.
- `roles/journald` — pins `Storage=persistent` so logs survive reboots.
- `roles/bootstrap_retirement` — opt-in (`BOOTSTRAP_RETIRE=true`
  `BOOTSTRAP_USER=<name>`): locks the provider bootstrap user once the
  baseline accounts are validated; `mise run vm:retire-bootstrap` for the
  lab VM. Run `vm:validate-reboot` first.

The baseline stays as close to distro defaults as possible: roles pin only
off-default invariants; anything a default already guarantees is trusted, not
asserted (see each role's README for what was deliberately left out).

`playbooks/cloud-init/render.sh` generates the first-boot user-data from the
same key files and sshd drop-in the roles own, which is what makes the first
converge a no-op.

`mise.toml` is contributor convenience only. It can call 1Password,
DigitalOcean, and Ansible for local development, but provider and
secret-manager behavior does not move into reusable collection roles.

## Versioning & releases

The collection is distributed from this git repository only — no galaxy
registry. Install it (or depend on it) via a git source:

```sh
ansible-galaxy collection install git+https://github.com/cur8s/ubuntu.git
```

The version is `24.4.x`: major.minor mirror the Ubuntu LTS the baseline targets
(24.04), and `x` counts collection releases. The baseline is **forever
backward-compatible within its LTS era** — that policy, not version
arithmetic, is the compatibility contract — so `x` only ever increments.
When the baseline advances to the next LTS (RFC-008: Release and
Versioning), a new series starts (`26.4.0`) and the previous series moves to
maintenance (fixes, no new controls).

`main` is the prod release. Each `galaxy.yml` version bump is tagged
`v<version>`, so environments that want reproducible pins or rollback
targets pin tags; dev environments track `main`.

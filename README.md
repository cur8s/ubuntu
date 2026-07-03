# Ubuntu Ansible Collection

This repository is the `baseline.ubuntu` Ansible collection: the floor every
Ubuntu host gets, regardless of what runs on top. Goals, architecture, and the
floor-inclusion test live in
`docs/rfcs/RFC-001 Baseline Goals and Architecture.md`.

The steel thread:

1. Extract SSH public keys from 1Password.
2. Render cloud-init user-data from the same sources the roles use.
3. Create a DigitalOcean Ubuntu VM; cloud-init creates the `ansible` and
   `sysadmin` users, applies the sshd hardening drop-in, dist-upgrades, and
   reboots (RFC-001 Model B).
4. Converge over the `ansible` SSH path. The first converge is a no-op for
   everything cloud-init already applied; only the behavioral floor controls
   do new work. Every subsequent converge is a no-op.

```sh
mise run key:extract
mise run key:upload
mise run vm:create   # renders cloud-init, creates the VM
mise run vm:converge
```

Acceptance test (opt-in; never part of routine converge):

```sh
mise run vm:validate-reboot   # reboot → re-verify access + floor services
```

SSH shortcuts:

```sh
mise run ssh:root      # provider bootstrap path (until retirement)
mise run ssh:ansible
mise run ssh:sysadmin
```

## Ansible Shape

The floor roles, applied by `playbooks/converge.yml`:

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

The floor stays as close to distro defaults as possible: roles pin only
off-default invariants; anything a default already guarantees is trusted, not
asserted (see each role's README for what was deliberately left out).

`playbooks/cloud-init/render.sh` generates the first-boot user-data from the
same key files and sshd drop-in the roles own, which is what makes the first
converge a no-op.

`mise.toml` is contributor convenience only. It can call 1Password,
DigitalOcean, and Ansible for local development, but provider and
secret-manager behavior does not move into reusable collection roles.

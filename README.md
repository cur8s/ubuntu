# Ubuntu Ansible Collection

This repository is the `cur8s.ubuntu` Ansible collection: the baseline every
Ubuntu host gets, regardless of what runs on top. Everything needed to
develop, verify, release, and consume the collection is self-contained here:
the installable collection lives in `collection/`, the how-to lives in
`docs/operations/manual.md`, and runnable consumption examples live in
`examples/`.

**To understand the system**, read the mental model below, then
`docs/rfcs/RFC-001 The Host Baseline.md` and onward for depth. **To change
the system**, start instead at `docs/rfcs/RFC-000 The Role of RFCs.md` —
the RFCs are the normative architecture contract, and changes must keep
them true.

## The mental model

**The baseline is the invariant state every managed Ubuntu host gets** — a
known, hardened, reproducible starting point. A host either conforms or it
doesn't; if it came from this baseline, it's fit for production. Think of
it as a floor: everything else builds above it, and nothing ever goes
below it.

**A host is born conformant, then kept conformant.** At first boot,
cloud-init — rendered from the very same files the Ansible roles own —
creates the access accounts, applies the SSH policy, patches everything,
and reboots (which doubles as a smoke test: if the box doesn't come back,
nothing else proceeds). From then on, *converge* re-asserts the declared
state over plain SSH, forever. Git is the source of truth: an out-of-band
change by a person or an AI agent is drift, and the next converge reverts
it. On a healthy host every converge reports zero changes, so a non-zero
report *is* the drift alarm — and check mode gives the same report without
touching anything.

**The baseline is deliberately small, and stays close to Ubuntu's
defaults.** It pins only what must be guaranteed: two fixed accounts
(`ansible` for automation, `sysadmin` for human break-glass), key-only
SSH, automatic security updates that never reboot on their own, and logs
that survive reboots. Everything a default already guarantees is trusted,
not asserted — nothing declared means nothing to maintain. It refuses, on
purpose, to own time sync, auditd, firewalls, or kernel tuning: those
belong to the layers above, and a baseline that fought them would be a
bug factory.

**Trust starts with the provider and ends with the baseline.** A new VM is
reachable only through the provider's bootstrap account. Once both baseline
accounts are proven working, that provider door can be retired — locked,
never deleted — and the host looks identical regardless of which cloud it
came from. All keys are ed25519; private keys live in the operator's
secrets manager and never touch this repository. Per-person identity is
deliberately not the baseline's job — that's for an access layer like a
tailnet, layered on top.

**Verification is deliberate, not ambient.** Baseline roles declare state;
they don't second-guess it. Proving the promises hold is the job of
opt-in acceptance gates — chiefly reboot validation, which reboots the
host and verifies access, services, and log history survived. Anything
dangerous (like retiring the bootstrap door) requires that gate first, and
the collection's only reboot path is the one that validates.

**Everything composes upward.** Purpose layers (a k3s node, a database
host) re-assert the baseline first, then add their own state — see
`examples/` for eight runnable demonstrations of the pattern. Environment
repositories sit on top, holding the inventory, keys, and schedule.
Because every tier re-asserts the baseline, it holds on every host, on
every converge.

**It ships as git, versioned by the Ubuntu it targets.** No registry:
install straight from this repository. Version `24.4.x` means "the 24.04
baseline, release x" — forever backward-compatible within its LTS era.
`main` is the production release; tags mark pinnable versions.

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
mise run do:prep   # once: 1Password keys + DigitalOcean bootstrap key
mise run do:up     # create → wait out first boot → converge
```

(Bare `mise run` prints the workflow cheat sheet for both labs.)

Acceptance test (opt-in; never part of routine converge):

```sh
mise run do:validate-reboot   # reboot → re-verify access + baseline services
```

The same thread runs provider-free on a local QEMU VM — the arm64 cloud
image under native virtualization, first-boot config via a NoCloud seed
built from the identical rendered cloud-init (`mise run qemu:prep` once,
then `mise run qemu:up`; see the operations manual).

SSH shortcuts:

```sh
mise run do:ssh:root      # provider bootstrap path (until retirement)
mise run do:ssh:ansible
mise run do:ssh:sysadmin
```

## Ansible Shape

The baseline roles, applied by `collection/playbooks/converge.yml`:

- `collection/roles/users` — the fixed `ansible` (automation) and `sysadmin`
  (break-glass) accounts: creation, authorized keys, passwordless sudo.
- `collection/roles/ssh` — the OpenSSH daemon policy drop-in (also embedded by
  cloud-init at first boot), validated with `sshd -t` and asserted with
  `sshd -T`.
- `collection/roles/unattended_upgrades` — automatic security updates; reboots are never
  automatic.
- `collection/roles/journald` — pins `Storage=persistent` so logs survive reboots.
- `collection/roles/bootstrap_retirement` — opt-in (`BOOTSTRAP_RETIRE=true`
  `BOOTSTRAP_USER=<name>`): locks the provider bootstrap user once the
  baseline accounts are validated; `mise run do:retire-bootstrap` for the
  lab VM. Run `do:validate-reboot` first.

The baseline stays as close to distro defaults as possible: roles pin only
off-default invariants; anything a default already guarantees is trusted, not
asserted (see each role's README for what was deliberately left out).

`collection/scripts/render-cloud-init.sh` generates the first-boot user-data from the
same key files and sshd drop-in the roles own, which is what makes the first
converge a no-op.

`mise.toml` is contributor convenience only. It can call 1Password,
DigitalOcean, and Ansible for local development, but provider and
secret-manager behavior does not move into reusable collection roles.

## Versioning & releases

The collection is distributed from this git repository only — no galaxy
registry. Install it (or depend on it) via a git source:

```sh
ansible-galaxy collection install 'git+https://github.com/cur8s/ubuntu.git#/collection/'
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

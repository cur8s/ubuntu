# Operations Manual

How to develop, verify, release, and consume `cur8s.ubuntu`. The RFCs in
`docs/rfcs/` own the what and the why; this manual owns the how. All commands
run from the repository root.

## 1. Prerequisites

Workstation CLIs (managed outside `mise` for now): `mise`, `op` (1Password),
`doctl` (DigitalOcean), `jq`, `ansible-playbook` (ansible-core ≥ 2.16), `ssh`.

- `doctl` authenticated against the target DigitalOcean account
  (`doctl auth init`).
- 1Password: a `devops` vault containing SSH key items `ubuntu-bootstrap`,
  `ubuntu-ansible`, and `ubuntu-sysadmin`, each exposing a `public key` field.
  All keys are `ssh-ed25519` (RFC-004). Private keys never leave 1Password;
  SSH authenticates through the 1Password SSH agent, so expect an agent
  authorization prompt on first use per session.
- Generated files land under `.generated/` (git-ignored). Only public keys
  and rendered user-data are ever written there — no secrets.

## 2. Keys

| 1Password item | Host account | Purpose |
| --- | --- | --- |
| `ubuntu-bootstrap` | provider bootstrap user (`root` on DigitalOcean) | first SSH path to a brand-new VM |
| `ubuntu-ansible` | `ansible` | converge automation |
| `ubuntu-sysadmin` | `sysadmin` | human break-glass |

```sh
mise run key:extract   # pull the three public keys into .generated/ssh/
mise run key:upload    # register the bootstrap public key with DigitalOcean (once per account)
```

`key:delete` removes the bootstrap key from DigitalOcean if it must be
rotated or retired provider-side.

## 3. Provision the test VM

```sh
mise run vm:create     # renders cloud-init, then creates the droplet
mise run vm:list       # ID, IP, status
```

`vm:create` renders `.generated/cloud-init/ubuntu-baseline.yaml` from the same
sources the roles own (RFC-005) and creates droplet `ubuntu-ansible-lab`
(Ubuntu 24.04, `s-1vcpu-1gb`, `tor1`). At first boot, cloud-init creates the
`ansible` and `sysadmin` accounts, lays down the sshd drop-in, dist-upgrades,
and reboots unconditionally. Allow a few minutes before the first converge —
the droplet reaching `active` predates the first-boot reboot finishing.

## 4. Converge

```sh
mise run vm:converge
```

What healthy runs look like:

- **First converge on a fresh VM:** only the converge-only baseline controls
  report `changed` (the unattended-upgrades and journald pins). Accounts and
  SSH policy are already no-ops — cloud-init applied them from the same
  sources (RFC-005).
- **Every converge after that:** `changed=0`. A non-zero count on a
  steady-state host is a drift report — read it, don't rerun past it.

Drift detection without enforcement (RFC-006):

```sh
mise x -- sh -c 'ansible-playbook \
  -i "$(doctl compute droplet list "$DROPLET_NAME" --format PublicIPv4 --no-header)," \
  collection/playbooks/converge.yml --check --diff'
```

If the workstation sits behind a rate-limiter or IPS that drops SSH bursts,
set `SSH_SPACING_SECONDS` (default `0`) to pause before SSH-heavy tasks:
`SSH_SPACING_SECONDS=120 mise run vm:converge`. Background: see
`docs/notes/ucg-fibre-ips-ssh-blocking.md`.

Converge refuses hosts that don't run the targeted Ubuntu release (the
release guard — RFC-002, RFC-008): applying the 24.4.x series to a 22.04 or
26.04 host fails before anything is mutated.

**Patching.** The automatic baseline covers security updates only. For a
deliberate full update:

```sh
mise run vm:update
```

It never reboots; if updates leave a reboot pending it says so — run
`mise run vm:validate-reboot`, the collection's only (and validating)
reboot path.

## 5. Acceptance validation

```sh
mise run vm:validate-reboot
```

The reboot-validation gate (RFC-007): reboots the host, waits for it to
return, re-verifies `ansible` and `sysadmin` SSH + passwordless sudo,
confirms the baseline units are active, and reads the previous boot from the
journal (proving the persistence pin across reboots). Opt-in only — never
part of routine converge. Run it before enabling bootstrap retirement in any
environment.

## 6. Bootstrap retirement

Point of no return for the provider SSH path (RFC-004). Preconditions: the
target has passed `vm:validate-reboot`, and both named accounts validated in
converge.

```sh
mise run vm:retire-bootstrap   # asks for confirmation
```

This converges with `BOOTSTRAP_RETIRE=true BOOTSTRAP_USER=root`: after the
account validations pass, it strips root's `authorized_keys`, removes the
cloud-init sudoers file, and locks the account. Afterward `mise run ssh:root`
stops working — by design — and recovery is the provider console. Routine
`vm:converge` never retires anything (the toggle defaults off).

## 7. SSH shortcuts and teardown

```sh
mise run ssh:root       # provider bootstrap path (dead after retirement)
mise run ssh:ansible
mise run ssh:sysadmin

mise run vm:reboot      # provider-level reboot (no validation; prefer vm:validate-reboot)
mise run vm:delete      # destroy the droplet (asks for confirmation)
mise run clean          # vm:delete + remove .generated/
```

The droplet is disposable by design: recreating the full verified state is
`vm:create` + `vm:converge`, about five minutes.

## 8. Examples

Runnable consumer-shaped examples live in `examples/` (its README indexes
them by theme and technique). Run one against the lab VM:

```sh
mise run example:run docker
```

`example:run` depends on `example:link`, which symlinks the working-tree
collection into `.generated/collections/` so each example's
`import_playbook: cur8s.ubuntu.converge` resolves against your live edits —
no commit or reinstall between iterations. Every example is idempotent by
contract: run it twice and the second pass reports `changed=0`.

## 9. Releasing

Versioning and distribution policy: RFC-008 (`24.4.x`, git-only, main is
prod).

1. Bump `version:` in `galaxy.yml` (next `24.4.x`).
2. Verify the artifact builds clean:
   `mise x -- ansible-galaxy collection build collection/ --output-path /tmp` and inspect
   the tarball contents if `build_ignore` changed.
3. Commit, then tag and push:

```sh
git tag -a v24.4.1 -m "cur8s.ubuntu 24.4.1"
git push origin main --tags
```

## 10. Consuming the collection

Install directly from git (no registry — RFC-008):

```sh
ansible-galaxy collection install 'git+https://github.com/cur8s/ubuntu.git#/collection/'
```

or in a consumer's `requirements.yml` (see `examples/`):

```yaml
collections:
  - name: https://github.com/cur8s/ubuntu.git#/collection/
    type: git
    version: main
```

Once release tags exist, pin one (`version: v24.4.0`) for reproducible
installs and rollback targets.

The stable consumer surface — playbook FQCNs (`cur8s.ubuntu.converge`,
`cur8s.ubuntu.validate_reboot`), account names, paths, and environment
variable inputs — is enumerated in RFC-009: Conventions Contract. The
`examples/` directory holds a runnable environment-repo-shaped skeleton
demonstrating the composition pattern.

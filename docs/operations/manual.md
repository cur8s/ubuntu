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

Bare `mise run` prints the workflow cheat sheet — the golden path through
both labs. `mise tasks` lists the operator-level tasks; the plumbing tasks
that workflow tasks pull in as dependencies (`key:prep`,
`cloud-init:render`, `do:key:upload`, `qemu:fetch`) are hidden from the
listing but remain runnable by name.

## 2. Keys

| 1Password item | Host account | Purpose |
| --- | --- | --- |
| `ubuntu-bootstrap` | provider bootstrap user (`root` on DigitalOcean) | first SSH path to a brand-new VM |
| `ubuntu-ansible` | `ansible` | converge automation |
| `ubuntu-sysadmin` | `sysadmin` | human break-glass |

Each lab has a one-time prep task that handles everything slow or
attention-requiring up front:

```sh
mise run do:prep     # 1Password keys + DigitalOcean bootstrap key (once per account)
mise run qemu:prep   # 1Password keys + cloud image download (local lab)
```

Both are safe to rerun (the key extraction refreshes, everything else
no-ops) — after `mise run clean`, rerunning the prep of whichever lab you
use restores the groundwork. Under the hood they share `key:prep` (the
1Password extraction — expect one agent approval). `do:key:delete` removes
the bootstrap key from DigitalOcean if it must be rotated or retired
provider-side.

## 3. Provision the test VM

```sh
mise run do:up         # create → wait out first boot → converge
mise run do:vm:status  # stages done so far, and the next step
```

`do:up` is the whole sequence: `do:vm:create` renders
`.generated/cloud-init/ubuntu-baseline.yaml` from the same sources the roles
own (RFC-005) and creates droplet `ubuntu-ansible-lab` (Ubuntu 24.04,
`s-1vcpu-1gb`, `tor1`); at first boot, cloud-init creates the `ansible` and
`sysadmin` accounts, lays down the sshd drop-in, dist-upgrades, and reboots
unconditionally; `do:vm:wait` blocks until that first-boot cycle is done (the
droplet reaching `active` predates it by minutes); `do:play:converge` runs the
first converge. The steps remain runnable individually for debugging — each
one's description names what normally follows it.

## 4. Converge

```sh
mise run do:play:converge
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
`SSH_SPACING_SECONDS=120 mise run do:play:converge`. Background: see
`docs/notes/ucg-fibre-ips-ssh-blocking.md`.

Converge refuses hosts that don't run the targeted Ubuntu release (the
release guard — RFC-002, RFC-008): applying the 24.4.x series to a 22.04 or
26.04 host fails before anything is mutated.

**Patching.** The automatic baseline covers security updates only. For a
deliberate full update:

```sh
mise run do:play:update
```

It never reboots; if updates leave a reboot pending it says so — run
`mise run do:play:validate-reboot`, the collection's only (and validating)
reboot path.

## 5. Acceptance validation

```sh
mise run do:play:validate-reboot
```

The reboot-validation gate (RFC-007): reboots the host, waits for it to
return, re-verifies `ansible` and `sysadmin` SSH + passwordless sudo,
confirms the baseline units are active, and reads the previous boot from the
journal (proving the persistence pin across reboots). Opt-in only — never
part of routine converge. Run it before enabling bootstrap retirement in any
environment.

## 6. Bootstrap retirement

Point of no return for the provider SSH path (RFC-004). Preconditions: the
target has passed `do:play:validate-reboot`, and both named accounts validated in
converge.

```sh
mise run do:play:retire-bootstrap   # asks for confirmation
```

This converges with `BOOTSTRAP_RETIRE=true BOOTSTRAP_USER=root`: after the
account validations pass, it strips root's `authorized_keys`, removes the
cloud-init sudoers file, and locks the account. Afterward `mise run do:ssh:root`
stops working — by design — and recovery is the provider console. Routine
`do:play:converge` never retires anything (the toggle defaults off).

## 7. SSH shortcuts and teardown

```sh
mise run do:ssh:root       # provider bootstrap path (dead after retirement)
mise run do:ssh:ansible
mise run do:ssh:sysadmin

mise run do:vm:reboot   # provider-level reboot (no validation; prefer do:play:validate-reboot)
mise run do:vm:destroy  # destroy the droplet (asks for confirmation)
mise run clean          # do:vm:destroy + qemu:vm:destroy + remove .generated/
```

The droplet is disposable by design: recreating the full verified state is
one `do:up`, about five minutes.

## 8. Local QEMU lab

The provider-free mirror of sections 3–5: the same rendered cloud-init, the
same playbooks, against a local VM instead of a droplet. Requires `qemu`
(Homebrew) on Apple Silicon — the guest is the Ubuntu 24.04 **arm64** cloud
image running at native speed under Hypervisor.framework, so the droplet
(amd64) and the local lab (arm64) together exercise the baseline on both
architectures.

```sh
mise run qemu:prep   # once: 1Password keys + cloud image download
mise run qemu:up     # create → boot (SSH on 127.0.0.1:2222) → wait → converge
```

`qemu:up` runs `qemu:vm:create` (NoCloud seed ISO + overlay disk from the
rendered cloud-init), `qemu:vm:boot` (daemonized), `qemu:vm:wait` (blocks through
the first-boot dist-upgrade and reboot), then `qemu:play:converge` — each step
runnable individually for debugging. From there: `validate-reboot`,
`update`, `ssh:*`, as with `do:*`.

Differences from the droplet flow:

- **No bootstrap door.** NoCloud has no provider-injected account; the
  rendered user-data defines the only users that ever exist. There is no
  `qemu` counterpart to `do:ssh:root` or `do:play:retire-bootstrap` — nothing to
  retire.
- **Serial console.** `mise run qemu:vm:console` follows the boot console —
  the debugging window when SSH isn't up.
- **Teardown is local.** `mise run qemu:vm:destroy` kills the VM and deletes
  its state; the cached cloud image survives, so destroy → create → boot →
  wait → converge is a fully offline few-minute loop. `clean` destroys the
  QEMU VM too (and drops the image cache with the rest of `.generated/`).

VM sizing and the forwarded port are `QEMU_*` variables in `mise.toml`.

## 9. Examples

Runnable consumer-shaped examples live in `examples/` (its README indexes
them by theme and technique). Each example has a test task per lab —
tab-complete `do:test:` or `qemu:test:` to see the catalog:

```sh
mise run do:test:docker       # against the droplet
mise run qemu:test:docker     # against the local QEMU VM
mise run qemu:test:examples   # every example, in one run
```

Every `test:` task enforces the examples' idempotency contract: it runs
the example twice and fails unless the second pass reports `changed=0`.
The suite (`test:examples`) covers the `examples/` directory by globbing —
an example without a per-name wrapper is still tested, with a warning — and
skips `tailscale` unless `TAILSCALE_AUTHKEY` is set (a join from a
disposable VM leaves a node in the tailnet admin console unless the key is
ephemeral). Examples must work on both supported architectures (RFC-008),
and the two labs cover them: droplet amd64, QEMU arm64.

The test tasks depend on a hidden `example:link` task that symlinks the
working-tree collection into `.generated/collections/` so each example's
`import_playbook: cur8s.ubuntu.converge` resolves against your live edits —
no commit or reinstall between iterations. Adding an example means adding
its two `mise-tasks/<lab>/test/<name>` wrappers alongside the directory.

## 10. Releasing

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

## 11. Consuming the collection

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

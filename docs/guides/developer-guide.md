# Developer Guide

How to work on this repository — for humans and coding agents alike.
`AGENTS.md` at the repo root is the short form agents load per request
(`CLAUDE.md` carries the same content, kept in lockstep); this guide is
the long form. For the big picture first, `docs/guides/architecture.md`
is the end-to-end map. This guide owns the how of *changing* the system;
`docs/guides/user-guide.md` owns the how of *using* it; the RFCs in
`docs/rfcs/` own the what and the why, and win every conflict.

## 1. How this repository decides things

The documentation taxonomy (RFC-000): **RFCs** are normative — they
prescribe what must remain true, never how it happens to be implemented.
**Guides** (this directory) own operational how-to. **Notes**
(`docs/notes/`) preserve evidence and designs that are not commitments.
**Examples** illustrate and prescribe nothing. A change that would violate
an accepted RFC is an architectural change: amend the RFC first, as its
own reviewed step.

The working rhythm, proven across every feature here: **align on the
design in conversation → write the RFC or design change (a commit the
operator approves) → implement → prove it live on a lab → commit with the
proof in the message, docs updated in the same change.** Until the first
release ships, RFCs are edited in place without revision-history noise
(a freedom that ends at `v24.4.0`); RFC numbers are stable identifiers
either way, never renumbered or reused (RFC-000).

Two standards with teeth:

- **Names are the interface.** Task names read as sentences under the
  grammar `<object>:<action>` (the header comment in `mise.toml` is
  authoritative; cloud harnesses are folder-namespaced, the same grammar
  inside). Descriptions say only what the name cannot; a namespace must
  have multiple real members. When a name or layout is confusing, that
  is a defect — rename until it reads plainly.
- **`changed=0` is the contract.** Everything idempotent proves it by
  running twice; test tasks enforce it mechanically. A proof on a real
  lab precedes every commit — recap lines belong in the commit message.

## 2. Workstation setup

CLIs (managed outside `mise` for now): `mise`, `ansible-playbook`
(ansible-core ≥ 2.16), `ssh`, `git`, `qemu` (Homebrew, Apple Silicon) for
the local lab. The sandbox DigitalOcean harness lists its own extras
(`doctl` + `jq`, and `op` for its default 1Password custody) — you need
them only when you run it.

- **The everyday loop needs no vault and no cloud.** The QEMU lab
  generates throwaway keypairs and runs its own promptless ssh-agent
  (RFC-004: ephemeral test credentials), so the entire local loop is
  unattended — no prompts, no billing.
- Everything generated lands in git-ignored `.generated/` (the
  provider harnesses keep their own, inside themselves); `mise run
  clean` destroys the local VM and wipes the root one. Recover with
  `up` — it fetches keys and image on demand.

## 3. The task surface

Bare `mise run` prints the cheat sheet — the curated golden path
through the labs. `mise tasks` lists the full surface; the one task
off the golden path is `vm:fetch-image`, an optional image pre-warm
that `up` also pulls in as a dependency. The grammar:

- the local QEMU lab (free; guest arch follows the host — arm64 on
  Apple silicon, amd64 in CI) is the root harness's only lab.
  Cloud-provider harnesses are self-contained, consumer-shaped folders
  that live with the operator's cloud custody (the sandbox, later the
  environment repository) — the folder is the namespace, and inside one
  the same `<object>:<action>` grammar applies.
- objects: `vm` (the machine, provider plane), `host` (baseline
  operations on the managed system — each task runs its `cur8s.ubuntu.*`
  playbook one-to-one; the one alias is `host:report-drift`, converge
  in check mode), `ssh` (a shell, by account), `test` (the proof
  suites — §6's ladder).
- the one provider workflow with no object: `up` (provision +
  converge; fetches keys and image on demand). Workstation-scoped:
  `clean` and `default`.

## 4. The QEMU lab — the everyday loop

The VM mechanics live in `mise-tasks/vendor/qemu-vm.sh` — a vendored
copy of
the `cur8s/qemu` product (one bash file: fetch-image / build-vm / start-vm
/ wait-until-ready / ssh / status / show-boot-log / destroy-vm /
help, `QVM_*` env config, guest arch
following the host). It was developed here, then extracted; this repo
is now its first consumer. The mise tasks are thin wrappers handing it
the lab's paths and rendered user-data. Do not edit the file here —
patches go upstream, and its header carries the pinned refresh
command.

```sh
mise run up     # build → start (127.0.0.1:2222) → wait → converge
                # (first run fetches the ~600MB image;
                #  optional pre-warm: mise run vm:fetch-image)
```

Mechanics worth knowing when debugging:

- **Keys and agent**: `activate_test_credentials` — defined by
  `collection/scripts/activate-test-credentials.sh`, the custody shim
  that ships with the collection so any consumer lab (this repo, the
  future k3s repo) inherits it by installing `cur8s.ubuntu` —
  generates three ed25519 keypairs into `.generated/qemu/keys/` and
  keeps a dedicated `ssh-agent` on `agent.sock` holding them; it also
  exports `QVM_SSH_IDENTITY_AGENT` so the vendored `qemu-vm.sh ssh`
  signs through the same agent. The agent is
  load-bearing: the collection connects pub-as-identity, and OpenSSH
  resolves a `.pub` identity only through an agent — it is the lab's
  stand-in for the secrets manager's signer. Every lab SSH pins
  `-o IdentityAgent=` to that socket — necessary because 1Password's
  `~/.ssh/config` installs a global `IdentityAgent` that overrides
  `SSH_AUTH_SOCK`. Public keys are kept 0600 to match vault-extracted
  pubs — convention, not necessity: with the agent holding the private
  half, ssh accepts a world-readable `.pub` identity (re-verified live
  2026-07-07); without an agent a `.pub` identity fails as "invalid
  format" regardless of permissions.
- **Per-lab render**: the lab renders its own
  `.generated/cloud-init/ubuntu-baseline-qemu.yaml`; the DigitalOcean
  folder renders its own user-data inside itself.
- **The inventory alias is load-bearing**: an inventory host literally
  named `127.0.0.1` is treated by Ansible as a localhost alias, so the
  lab inventory names the host `ubuntu-qemu-lab` with
  `ansible_host=127.0.0.1`.
- **Consoles and state**: `vm:show-boot-log` follows the boot log — the
  debug window when SSH is down. `vm:status` reports stages done, which
  VM occupies the slot (the harness's name row, read from the built
  VM's own seed), and the next command. Per-VM `known_hosts` lives in the VM dir and dies
  with it. `vm:destroy` keeps the image cache: destroy → up is an
  offline few-minute loop.
- **Confirm-guarded tasks need a yes**: `vm:destroy` and
  `host:lock-accounts` prompt before acting. Without a terminal mise
  aborts instead of asking, so unattended runs set `MISE_YES=1`.

**The adoption rehearsals** — faithful "existing servers", one per door
shape the clouds hand you (RFC-007). Two door shapes: `root-user` (the
DigitalOcean shape: bootstrap key on root, no sudo chain anywhere) and
`sudo-user` (the AWS/installer shape by default; the Azure shape with
`DOOR_USER=azureuser` — nothing in the collection may care which,
and that is what the parameter proves). One command runs both stories
sequentially, each asserted and destroyed on its own:

```sh
mise run test:adoption
```

Or walk one by hand:

```sh
mise run vm:build-adoptable sudo-user && mise run vm:start
mise run host:adoptable     # verdict; ADOPT_USER defaults to ubuntu
mise run host:adopt
mise run host:converge      # the delta the verdict predicted, then 0
mise run host:reboot-and-verify
mise run host:lock-accounts # closes the rehearsal door (the default)
```

(For the root-user shape, set `ADOPT_USER=root` and
`LOCK_ACCOUNTS=root` on the corresponding steps.)

**The refusal rehearsal** — the opposite story. `mise run test:adoption-refusals`
builds a server born with every plantable defect (`vm:build-unadoptable`:
both baseline accounts squatted with the fixture rogue key, both include
lines broken, a competing sshd drop-in, a pending reboot; root is the
door because the sudoers spoil would sever a sudo user's own become
chain) and asserts the sad path end to end: `adoptable` exits nonzero
naming every verdict code, and `adopt` refuses on identical grounds with
`changed=0` and a byte-identical account surface — never merged into,
never stripped (RFC-007). The same world exists judgment-side as the
`everything-wrong` fixture case, so drift between the layers fails one
of them.

## 5. The real-provider release gate

RFC-009's amd64/real-provider leg runs from a consumer-shaped
DigitalOcean harness that installs the collection from git via its own
`requirements.yml` — no dev link, so the gate proves exactly what
consumers get. The harness began life in this repository as
`test/integration/digital-ocean/` (history at `b0ba5ff`) and moved to
the operator's sandbox repository, which owns the DigitalOcean account
and 1Password custody. Its entry point, inside the folder:

```sh
mise run test    # prep -> create -> first boot -> converge x2 (changed=0)
                 # -> reboot-and-verify -> lock root -> report (two doors)
                 # -> destroy on success, keep on failure
```

Before tagging a release: run it against the release-candidate ref
(pin the harness's `requirements.yml`). First proven from the sandbox
against `b0ba5ff` on 2026-07-05. The gate covers what no lab can — the
real provider datasource and image quirks; the amd64 architecture leg
is already covered continuously by CI (§6).

## 6. Testing

Tests are organized by **proof plane** — where a claim is cheapest to
prove without lying about it. Three planes, fast to slow, each trading
speed for fidelity; a suite lives at the fastest plane that can
actually prove its claim.

- **The fixture plane — no VM, seconds.** `test:adoption-verdicts` and
  `test:render` run pure logic against fixtures on localhost: every
  adoptability verdict class (including the unsupported-release refusal
  no lab can boot) and every cloud-init input guard, proven before any
  VM exists. This plane is possible only because of a deliberate seam —
  the adoptability checks split probe (reads the host) from verdict
  (pure judgment over an `adopt_observations` dict), so the fixtures in
  `collection/tests/adoptability/` feed the verdict half directly.
- **The lab plane — the local QEMU VM, minutes.** The bulk of the suite
  boots a real Ubuntu host and proves behavior end to end:
  born-conformant convergence, both adoption rehearsals and the
  refusal, rotation, patch, the lock and reboot refusals, and the N=2
  fleet. The lab is free, unattended, and secretless (RFC-004 ephemeral
  credentials + the vendored `qemu-vm.sh`) — the load-bearing
  architectural choice, because "prove it on a real host" then costs
  nothing and needs no cloud account, so every push runs the whole
  ladder. Guest arch follows the host — arm64 on Apple silicon, amd64
  on CI's KVM runner — so the same suites prove both shipped
  architectures, and nothing may assume an architecture it did not
  detect (RFC-010).
- **The real-provider plane — DigitalOcean, release cadence.** The one
  thing no lab can fake: the real datasource, the provider's own image
  and cloud-init, real network. It runs from the sandbox harness (§5)
  at release time only; everything else is proven cheaper, and this
  plane's unique coverage is the provider realities alone (RFC-009).

**Fixtures mirror the lab worlds, so the fast plane is not a weaker
test.** The `everything-wrong` fixture case is the same world
`vm:build-unadoptable` boots; the fixture plane asserts the verdict, the
lab plane (`test:adoption-refusals`) asserts the boot-level reality —
real probes, real exit codes, adopt adding nothing. Drift between the
two fails one of them: the fast plane and the slow plane check the same
claim from opposite sides, not two different claims. The one documented
residual is the unsupported release — no proof plane boots a non-24.04
image, so that refusal is proven at the fixture layer only.

**What a passing suite is allowed to mean.** A green suite is worth only
its assertions, so every suite is written to a shared discipline that
keeps a PASS honest:

- **`changed=0` is the contract.** Every idempotent claim is proven by
  running twice; the second pass must report zero across every host in
  the recap. `assert_changed_zero` (`mise-tasks/test/suite-asserts.sh`)
  refuses a recap-less log loudly rather than scanning nothing and
  passing vacuously.
- **Assert on failure evidence, never a task banner.** A banner prints
  whether its task passed *or* failed, so keying an attribution on it
  false-passes a regression that failed later for another reason. The
  refusal suites key on the `fail_msg` text, the per-item `failed:`
  line, or the probe's own `fatal:` — the thing that appears only when
  the *intended* check is what failed.
- **Capture, then test — never pipe to `grep -q` under `pipefail`.** An
  early-exiting `grep` can `SIGPIPE` the command feeding it and fail the
  pipeline it was reading; the suites capture to a variable and test the
  variable.
- **No vacuous asserts.** `systemctl is-active` over several units exits
  0 if any one is active; a recap-level `changed>0` is satisfied by the
  apt-cache task that changes every run. Assertions target the specific
  unit and the specific task, never an aggregate a bystander can
  satisfy.
- **Access-mutating suites leave the lab as they found it.** Rotation
  and the lock refusals restore the standard doors and end `changed=0`
  (the standing lab survives); patch, fleet, and the adoption rehearsals
  build and destroy their own VMs. Either way a suite never strands the
  next one.

Shared helpers earn a place in `suite-asserts.sh` only once two suites
call them (the namespace-lib rule); until then a suite keeps its own.

**The CI ladder runs the planes fail-fast** (`.github/workflows/ci.yml`
— one amd64 KVM job, no secrets, no billable resources). Every push and
pull request runs the fixture plane first (`test:adoption-verdicts`,
`test:render` — they fail in the first minute, before any VM boots),
then the born-conformant path (`up`) and `test:examples`: fast feedback
in minutes. Pushes to `main` add the full rehearsal ladder — rotation,
adoption and its refusals, patch, the lock and reboot refusals,
bystanders, fleet. The real-provider plane is the release gate, not CI
(§5).

The suites, in detail.

Each example has a local test task (`test:example-docker`, ... and
`test:examples` for the whole catalog). Every one enforces the
idempotency contract: run twice, fail unless the second pass reports
`changed=0`. The suite globs `examples/` so coverage cannot silently
drop. Every
example run refreshes a symlink from `.generated/collections/` to the
working tree, so examples resolve your live edits — no reinstall
between iterations. `test:adoption` is the second suite:
both adoption rehearsals, each asserted end to end (§4).

`test:adoption-verdicts` is the fixture plane in practice: each case in
`collection/tests/adoptability/cases/` is one `adopt_observations`
world fed straight to the verdict half, asserting the stable bracketed
codes (RFC-007) and whether the refusal fires — never the prose.
`test:adoption-refusals` is its lab-plane twin (§4): the same worlds
booted, with real probes, real exit codes, and adopt refusing with
nothing added.

`test:rotation` covers the remaining access-mutating verb: both
baseline accounts re-keyed and back on the provisioned lab, each
rotation entered through the sibling door; a planted stranger key must
refuse with the account untouched, a bogus `ROTATE_ACCOUNT` must fail
the input policy, and the suite ends with the standard keys restored
and `changed=0` — non-destructive, the lab stays up.

`test:render` proves the cloud-init render's input guards: six
refusals by name (missing and empty key files, a non-ed25519 key, a
multi-line key file — the YAML-injection guard — plus both env slots),
and a control pinning the rendered document ASCII, parseable, and
deterministic. No VM. The same parse rule holds at build time: the
three vm build tasks source `mise-tasks/vm/seed-check.sh` and refuse an
unparseable seed instead of booting a doorless VM (the parser is
ansible-core's own Python — no new workstation requirement).

`test:patch` runs day two on a genuinely stale server: an adoptable
world built from the previous Ubuntu point release (pinned by serial
inside the suite; bump it and the CI cache key when a new point
release ships), adopted, then patched through a real months-deep
delta. Asserted: the play never reboots (`boot_id` unchanged), the
reboot-required report tells the truth in both directions, the
validating reboot actually reboots, a repeat patch is a no-op, and the
patched world converges with `changed=0`. The pinned serial is
checksum-verified against Ubuntu's own SHA256SUMS, so a bumped pin can
never silently serve stale cached bytes.

`test:lock-refusals` proves the door-closing guards without ever
closing a door: empty, baseline, mixed, and ghost target lists refused
by name; the lock-your-last-door safety (a sabotaged sysadmin proof
stops everything with the target untouched); and the connection-user
guard, reached by connecting as a throwaway account and asking the
play to lock it. Ends with the standard two-door surface and
`changed=0`.

`test:lock-bystanders` is the C17 world: two provisioning-time
accounts sharing cloud-init's combined sudoers file. Locking one
removes only its own grant — the bystander's sudo keeps working,
verified by sudo itself — a repeat lock reports `changed=0`, and the
combined file is deleted exactly when its last grant goes.

`test:reboot-refusal` proves the acceptance gate discriminates: with a
baseline service masked, `reboot_and_verify` must refuse — after a
real reboot (`boot_id` changes), at the service verification, not at
the connection — and after healing, the same gate must pass the same
host. The journal-history leg is deliberately not broken: wiping the
persistent journal would poison the next run's `--boot=-1` check too,
and all three verification legs refuse through the same mechanics.

`test:fleet` proves the fleet claim at N=2 — the smallest world where
multi-host bugs are visible at all (every other suite is one VM, where
a hostvars mixup or `run_once` bleed passes vacuously). Two fresh
provisioned slots on their own ports (the standing lab untouched — the
`QVM_*` values in `mise.toml` are defaults that yield to a caller's
environment, which is the whole slot seam), one inventory holding
both: converge to `changed=0` with both hosts required in the recap, a
direct attribution assert that every delegated access probe carried
its own host's port and never the sibling's, the access report judged
per host, and one rotation re-keying `ansible` across the whole fleet
through the sysadmin door and back.

## 7. Adding things

**A role**: pins only off-default invariants — no verification-only code
(RFC-002); its README records what was deliberately left out. Naming:
roles that enforce state are nouns (`users`, `ssh`, `journald`); a role
that performs a deliberate act is a verb, singular (`lock_account`, the
primitive under the plural playbook `lock_accounts`). If it owns
a file cloud-init also lays down, keep the render in lockstep
(`collection/scripts/render-cloud-init.sh` — the one-source-two-moments
discipline, RFC-006).

**A playbook**: follow the house patterns — release guard in pre_tasks,
input validation on localhost first, the shared
`validate-ssh-sudo-access` tasks for access proofs, refusals that name
what a human must decide. Add its FQCN and inputs to RFC-011, a `host:`
wrapper in the qemu family and the integration folders, and a user-guide
runbook section.

**An example**: a directory under `examples/` (site.yml + README) plus
its `mise-tasks/test/<name>` wrapper — the suites glob `examples/`,
so coverage is automatic either way. It must work on both architectures
(CI is the amd64 leg — §6).

**A provider harness**: copy the shape of the DigitalOcean harness
(repo history, `test/integration/digital-ocean/` at `b0ba5ff`) — a
self-contained mise config, object-grammar tasks, its own helpers and
state, custody wiring parameterized in `[env]`, an in-folder `test`
steel thread — living beside the operator's cloud custody, not in this
repo. The provider's bootstrap account becomes the default
`LOCK_ACCOUNTS` target. Gate it on a real workload needing that
provider (the TODO's multi-provider rule).

**An RFC**: next free number; keep the reading-order arc sensible (the
numbers follow it); state `Accepted` when in force; end with the Scope /
"It does not define" pattern naming the neighbors.

## 8. Releasing

Policy is RFC-010 (`24.4.x`, git-only, `main` is prod):

1. Pass the release gate (RFC-009): the sandbox DigitalOcean harness's
   `mise run test` against the release-candidate ref (the real-provider
   leg), plus green CI and `mise run test:adoption-verdicts`,
   `mise run test:render`, `mise run test:examples`, `mise run test:rotation`,
   `mise run test:adoption`, `mise run test:adoption-refusals`,
   `mise run test:patch`, `mise run test:lock-refusals`,
   `mise run test:lock-bystanders`, `mise run test:reboot-refusal`, and
   `mise run test:fleet` locally.
2. Bump `version:` in `collection/galaxy.yml`.
3. `mise x -- ansible-galaxy collection build collection/ --output-path
   /tmp` — inspect the tarball if `build_ignore` changed.
4. Commit, then `git tag -a v24.4.x -m "cur8s.ubuntu 24.4.x"` and
   `git push origin main --tags`.

## 9. For coding agents

You are a first-class contributor here, and the rhythm in §1 applies to
you exactly: propose designs before writing code, wait for approval,
prove everything on the QEMU lab (it needs no human present), report
recaps honestly, and never push unless asked. The operator treats
"confusing" as a defect report — when naming or output reads badly, fix
it rather than explain it.

# Developer Guide

How to work on this repository — for humans and coding agents alike.
`AGENTS.md` at the repo root is the short form agents load per request
(`CLAUDE.md` links to it); this guide is the long form. This guide owns
the how of *changing* the system; `docs/guides/user-guide.md` owns the how
of *using* it; the RFCs in `docs/rfcs/` own the what and the why, and win
every conflict.

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
release ships, RFCs are edited in place without revision-history noise,
and RFC numbers may be renumbered to keep the reading order (a freedom
that ends at `v24.4.0`).

Two standards with teeth:

- **Names are the interface.** Task names read as sentences under the
  grammar `<provider>:<object>:<action>` (the header comment in
  `mise.toml` is authoritative). Descriptions say only what the name
  cannot; a namespace must have multiple real members. When a name or
  layout is confusing, that is a defect — rename until it reads plainly.
- **`changed=0` is the contract.** Everything idempotent proves it by
  running twice; test tasks enforce it mechanically. A proof on a real
  lab precedes every commit — recap lines belong in the commit message.

## 2. Workstation setup

CLIs (managed outside `mise` for now): `mise`, `ansible-playbook`
(ansible-core ≥ 2.16), `ssh`, `git`, `qemu` (Homebrew, Apple Silicon) for
the local lab. The DigitalOcean integration folder lists its own extras
(`doctl` + `jq`, and `op` for its default 1Password custody) — you need
them only when you run it.

- **The everyday loop needs no vault and no cloud.** The QEMU lab
  generates throwaway keypairs and runs its own promptless ssh-agent
  (RFC-004: ephemeral test credentials), so the entire local loop is
  unattended — no prompts, no billing.
- Everything generated lands in git-ignored `.generated/` (the
  integration folders keep their own, inside themselves); `mise run
  clean` destroys the local VM and wipes the root one. Recover with
  `prep`.

## 3. The task surface

Bare `mise run` prints the cheat sheet — the golden path through the
labs. `mise tasks` lists the operator-level tasks; plumbing tasks pulled
in as dependencies (`keys`, `vm:fetch-image`, `example:link`) are
hidden but runnable by name. The grammar:

- the local QEMU lab (free; guest arch follows the host — arm64 on
  Apple silicon, amd64 in CI) is the root harness's only lab.
  Cloud-provider harnesses are self-contained, consumer-shaped folders
  that live with the operator's cloud custody (the sandbox, later the
  environment repository) — the folder is the namespace, so inside one
  the same grammar reads `<object>:<action>` with no prefix.
- objects: `vm` (the machine, provider plane), `host` (baseline
  operations on the managed system — each task runs its `cur8s.ubuntu.*`
  playbook; `host:check` is converge in check mode, the drift alarm),
  `ssh` (a shell, by account), `test` (examples, and the scenario
  chain).
- provider workflows with no object: `prep` (one-time groundwork), `up`
  (provision + converge). Workstation-scoped: `clean` and `default`.

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
mise run prep   # once: throwaway lab keys + cloud image (~600MB)
mise run up     # create → boot (127.0.0.1:2222) → wait → converge
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
  `SSH_AUTH_SOCK`. Public keys are 0600: ssh tries identity files as
  private keys and refuses world-readable ones.
- **Per-lab render**: the lab renders its own
  `.generated/cloud-init/ubuntu-baseline-qemu.yaml`; the DigitalOcean
  folder renders its own user-data inside itself.
- **The inventory alias is load-bearing**: an inventory host literally
  named `127.0.0.1` is treated by Ansible as a localhost alias, so the
  lab inventory names the host `ubuntu-qemu-lab` with
  `ansible_host=127.0.0.1`.
- **Consoles and state**: `vm:show-boot-log` follows the boot log — the
  debug window when SSH is down. `vm:status` reports stages done and
  the next command. Per-VM `known_hosts` lives in the VM dir and dies
  with it. `vm:destroy` keeps the image cache: destroy → up is an
  offline few-minute loop.
- **Confirm-guarded tasks need a yes**: `vm:destroy` and
  `host:lock-accounts` prompt before acting. Without a terminal mise
  aborts instead of asking, so unattended runs set `MISE_YES=1`.

**The adoption rehearsals** — faithful "existing servers", one per door
shape the clouds hand you (RFC-007). Two scenarios: `root-user` (the
DigitalOcean shape: bootstrap key on root, no sudo chain anywhere) and
`sudo-user` (the AWS/installer shape by default; the Azure shape with
`SCENARIO_USER=azureuser` — nothing in the collection may care which,
and that is what the parameter proves). One command runs both stories
sequentially, each asserted and destroyed on its own:

```sh
mise run test:scenarios
```

Or walk one by hand:

```sh
mise run vm:build-sudo-user-scenario && mise run vm:start
mise run host:adoptable     # verdict; ADOPT_USER defaults to ubuntu
mise run host:adopt
mise run host:converge      # the delta the verdict predicted, then 0
mise run host:validate-reboot
mise run host:lock-accounts # closes the scenario door (the default)
```

(For the root-user scenario, set `ADOPT_USER=root` and
`LOCK_ACCOUNTS=root` on the corresponding steps.)

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
                 # -> validate-reboot -> lock root -> report (two doors)
                 # -> destroy on success, keep on failure
```

Before tagging a release: run it against the release-candidate ref
(pin the harness's `requirements.yml`). First proven from the sandbox
against `b0ba5ff` on 2026-07-05. The gate covers what no lab can — the
real provider datasource and image quirks; the amd64 architecture leg
is already covered continuously by CI (§6).

## 6. Testing

Each example has a local test task (`test:docker`, ... and
`test:all` for the suite). Every one enforces the
idempotency contract: run twice, fail unless the second pass reports
`changed=0`. The suite globs `examples/` so coverage cannot silently
drop; `tailscale` is skipped without `TAILSCALE_AUTHKEY`. The hidden
`example:link` task symlinks the working tree into
`.generated/collections/`, so examples resolve your live edits — no
reinstall between iterations. `test:scenarios` is the second suite:
both adoption rehearsals, each asserted end to end (§4).

Architecture coverage (RFC-009, RFC-010): the lab's guest arch follows
the host, so the same tasks prove arm64 on Apple silicon and amd64 in
CI — `.github/workflows/ci.yml` runs `prep`, `up`, and `test:all` on
every push and pull request on an amd64 KVM runner (no secrets, no
billable resources), plus `test:scenarios` on pushes to main. The
sandbox DigitalOcean harness stays the real-provider leg at release
cadence (§5). Nothing may assume an architecture it did not detect.

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
   leg), plus green CI and `mise run test:all` and
   `mise run test:scenarios` locally.
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

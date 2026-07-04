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
the local lab, plus `op` (1Password) and `doctl` + `jq` only if you use
the droplet lab.

- The droplet lab needs a 1Password `devops` vault with SSH key items
  `ubuntu-bootstrap`, `ubuntu-ansible`, `ubuntu-sysadmin` (each exposing a
  `public key` field), and `doctl auth init`. Expect one SSH-agent
  approval per session.
- **The QEMU lab needs neither.** It generates throwaway keypairs and
  runs its own promptless ssh-agent (RFC-004: ephemeral lab credentials),
  so the entire local loop is unattended — no prompts, no vault.
- Everything generated lands in git-ignored `.generated/`; `mise run
  clean` destroys the lab VMs and wipes it. Recover with the prep of
  whichever lab you use.

## 3. The task surface

Bare `mise run` prints the cheat sheet — the golden path through the
labs. `mise tasks` lists the operator-level tasks; plumbing tasks pulled
in as dependencies (`key:prep`, `qemu:keys`, `cloud-init:render`,
`do:key:upload`, `qemu:fetch`, `example:link`) are hidden but runnable by
name. The grammar:

- providers `qemu` (local, arm64, free) and `do` (DigitalOcean, amd64);
  future clouds get their own family.
- objects: `vm` (machine lifecycle), `play` (collection playbooks, 1:1
  with `cur8s.ubuntu.*` FQCNs), `ssh` (a shell, by account), `test`
  (examples), `key` (provider keys).
- provider workflows with no object: `prep` (one-time groundwork), `up`
  (provision + converge). Workstation-scoped: `clean`, `default`.

## 4. The QEMU lab — the everyday loop

```sh
mise run qemu:prep   # once: throwaway lab keys + cloud image (~600MB)
mise run qemu:up     # create → boot (127.0.0.1:2222) → wait → converge
```

Mechanics worth knowing when debugging:

- **Keys and agent**: `qemu_keys_env` (in `mise-tasks/lib.sh`) generates
  three ed25519 keypairs into `.generated/qemu/keys/` and keeps a
  dedicated `ssh-agent` on `agent.sock` holding them. Every lab SSH pins
  `-o IdentityAgent=` to that socket — necessary because 1Password's
  `~/.ssh/config` installs a global `IdentityAgent` that overrides
  `SSH_AUTH_SOCK`. Public keys are 0600: ssh tries identity files as
  private keys and refuses world-readable ones.
- **Per-lab render**: the lab renders its own
  `.generated/cloud-init/ubuntu-baseline-qemu.yaml`; the droplet's render
  is never clobbered.
- **The inventory alias is load-bearing**: an inventory host literally
  named `127.0.0.1` is treated by Ansible as a localhost alias, so the
  lab inventory names the host `ubuntu-qemu-lab` with
  `ansible_host=127.0.0.1`.
- **Consoles and state**: `qemu:vm:console` follows the serial log — the
  debug window when SSH is down. `qemu:vm:status` reports stages done and
  the next command. Per-VM `known_hosts` lives in the VM dir and dies
  with it. `qemu:vm:destroy` keeps the image cache: destroy → up is an
  offline few-minute loop.

**The adoption rehearsal** — a faithful "existing server" (installer-style
sudo `ubuntu` user on the bootstrap key, password auth on, no baseline):

```sh
mise run qemu:vm:create-vanilla && mise run qemu:vm:boot
mise run qemu:play:adoptable     # verdict; ADOPT_USER defaults to ubuntu
mise run qemu:play:adopt
mise run qemu:play:converge      # the delta the verdict predicted, then 0
mise run qemu:play:validate-reboot
mise run qemu:play:lock-accounts # closes the ubuntu door (the default)
```

## 5. The droplet lab

```sh
mise run do:prep       # once: 1Password keys + DO bootstrap key upload
mise run do:up         # create → wait out first boot → converge (~5 min)
mise run do:vm:status  # stages done, next command
```

The droplet (`ubuntu-ansible-lab`, `s-1vcpu-1gb`, `tor1`) is billable —
`do:vm:destroy` when done; recreating verified state is one `do:up`. Its
provider bootstrap door is root; `do:play:lock-accounts` defaults to
locking it (acceptance gate first). If your network's IPS drops SSH
bursts, set `SSH_SPACING_SECONDS` (see
`docs/notes/ucg-fibre-ips-ssh-blocking.md`).

## 6. Testing

Each example has a per-provider test task (`qemu:test:docker`,
`do:test:zot`, ... and `test:all` for the suite). Every one enforces the
idempotency contract: run twice, fail unless the second pass reports
`changed=0`. The suite globs `examples/` so coverage cannot silently
drop; `tailscale` is skipped without `TAILSCALE_AUTHKEY`. The hidden
`example:link` task symlinks the working tree into
`.generated/collections/`, so examples resolve your live edits — no
reinstall between iterations. The two labs split architecture coverage:
droplet amd64, QEMU arm64 (RFC-010); nothing may assume an architecture
it did not detect.

## 7. Adding things

**A role**: pins only off-default invariants — no verification-only code
(RFC-002); its README records what was deliberately left out. If it owns
a file cloud-init also lays down, keep the render in lockstep
(`collection/scripts/render-cloud-init.sh` — the one-source-two-moments
discipline, RFC-006).

**A playbook**: follow the house patterns — release guard in pre_tasks,
input validation on localhost first, the shared
`validate-ssh-sudo-access` tasks for access proofs, refusals that name
what a human must decide. Add its FQCN and inputs to RFC-011, a `play:`
wrapper per provider, and a user-guide runbook section.

**An example**: a directory under `examples/` (site.yml + README +
requirements.yml) plus its two `mise-tasks/<provider>/test/<name>`
wrappers. It must work on both architectures.

**An RFC**: next free number; keep the reading-order arc sensible (the
numbers follow it); state `Accepted` when in force; end with the Scope /
"It does not define" pattern naming the neighbors.

## 8. Releasing

Policy is RFC-010 (`24.4.x`, git-only, `main` is prod):

1. Bump `version:` in `collection/galaxy.yml`.
2. `mise x -- ansible-galaxy collection build collection/ --output-path
   /tmp` — inspect the tarball if `build_ignore` changed.
3. Commit, then `git tag -a v24.4.x -m "cur8s.ubuntu 24.4.x"` and
   `git push origin main --tags`.

## 9. For coding agents

You are a first-class contributor here, and the rhythm in §1 applies to
you exactly: propose designs before writing code, wait for approval,
prove everything on the QEMU lab (it needs no human present), report
recaps honestly, and never push unless asked. The operator treats
"confusing" as a defect report — when naming or output reads badly, fix
it rather than explain it.

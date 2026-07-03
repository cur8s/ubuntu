# RFC-009: Conventions Contract

Status: Draft

Layers and consumers need names they can hardcode. This RFC enumerates the stable contract: everything listed here changes only through a revision to this RFC, because consumers are entitled to rely on it without configuration.

## Names

* The collection is `cur8s.ubuntu`, distributed from its git repository (RFC-008: Release and Versioning).
* The converge entry point is the collection playbook `cur8s.ubuntu.converge`.
* The reboot acceptance gate is the collection playbook `cur8s.ubuntu.validate_reboot`.
* The operator-invoked full package update is the collection playbook `cur8s.ubuntu.update`; it never reboots.
* The account names are `ansible` and `sysadmin`: always present, locked passwords, passwordless sudo (RFC-004: Identity and Trust).

## Paths

* Per-account sudoers rules: `/etc/sudoers.d/ansible` and `/etc/sudoers.d/sysadmin`.
* The OpenSSH policy drop-in: `/etc/ssh/sshd_config.d/10-ubuntu-baseline.conf`.
* The journald policy drop-in: `/etc/systemd/journald.conf.d/10-ubuntu-baseline.conf`.
* Baseline-owned apt policy: `/etc/apt/apt.conf.d/20auto-upgrades` and `/etc/apt/apt.conf.d/52-baseline-unattended-upgrades`.

## Inputs

The collection playbooks read their inputs from environment variables: `ANSIBLE_PUB_KEY` and `SYSADMIN_PUB_KEY` name the ed25519 public key files, and bootstrap retirement is gated by `BOOTSTRAP_RETIRE` with `BOOTSTRAP_USER` naming the provider bootstrap account (RFC-004: Identity and Trust).

This RFC remains a draft until the first use-case collection (`cur8s.k3s`) has consumed the contract and proven it sufficient. Consuming it is expected to surface whatever is missing.

## Scope

This RFC enumerates the names, paths, and inputs consumers may rely on.

It does not define the meaning of the controls behind them (RFC-003: Baseline Contents, RFC-004: Identity and Trust) or playbook implementation.

## Revisions

Initial draft.

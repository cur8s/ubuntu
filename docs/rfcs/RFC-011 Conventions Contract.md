# RFC-011: Conventions Contract

Status: Accepted

Layers and consumers need names they can hardcode. This RFC enumerates the stable contract: everything listed here changes only through a revision to this RFC, because consumers are entitled to rely on it without configuration.

## Names

* The collection is `cur8s.ubuntu`, distributed from its git repository (RFC-010: Release and Versioning).
* The converge entry point is the collection playbook `cur8s.ubuntu.converge`.
* The reboot acceptance gate is the collection playbook `cur8s.ubuntu.validate_reboot`.
* The operator-invoked full package update is the collection playbook `cur8s.ubuntu.update`; it never reboots.
* The door-closing playbook is `cur8s.ubuntu.lock_accounts` — standalone and never part of converge (RFC-005: Accounts and Access).
* The access-surface report is the read-only collection playbook `cur8s.ubuntu.report_access`; it always reports zero changes.
* The adoption assessment is the read-only collection playbook `cur8s.ubuntu.adoptable` — nonzero exit on hard failures — and adoption is `cur8s.ubuntu.adopt` (RFC-007: Adoption).
* The key-rotation playbook is `cur8s.ubuntu.rotate_key` — one baseline account per invocation, entered through the sibling account (RFC-004: Identity and Trust).
* The account names are `ansible` and `sysadmin`: always present, locked passwords, passwordless sudo (RFC-004: Identity and Trust).

## Paths

* Per-account sudoers rules: `/etc/sudoers.d/ansible` and `/etc/sudoers.d/sysadmin`.
* The OpenSSH policy drop-in: `/etc/ssh/sshd_config.d/10-ubuntu-baseline.conf`.
* The journald policy drop-in: `/etc/systemd/journald.conf.d/10-ubuntu-baseline.conf`.
* Baseline-owned apt policy: `/etc/apt/apt.conf.d/20auto-upgrades` and `/etc/apt/apt.conf.d/52-baseline-unattended-upgrades`.

## Inputs

The collection playbooks read their inputs from environment variables: `ANSIBLE_PUB_KEY` and `SYSADMIN_PUB_KEY` name the ed25519 public key files, `LOCK_ACCOUNTS` names the comma-separated accounts whose doors `cur8s.ubuntu.lock_accounts` closes (RFC-005: Accounts and Access), `ADOPT_USER` names the pre-baseline account adoption connects through (RFC-007: Adoption), and `ROTATE_ACCOUNT` with `ROTATE_NEW_PUB_KEY` name the baseline account and its replacement public key for `cur8s.ubuntu.rotate_key` (RFC-004: Identity and Trust).

The runnable examples in `examples/` are consumers of this contract — every one resolves the collection by FQCN, connects through the fixed accounts, and supplies inputs through the environment variables above. Future use-case collections that surface missing conventions add them through revisions to this RFC.

## Scope

This RFC enumerates the names, paths, and inputs consumers may rely on.

It does not define the meaning of the controls behind them (RFC-003: Baseline Contents, RFC-004: Identity and Trust) or playbook implementation.

## Revisions

Initial draft.

Accepted: the runnable examples consume the contract end-to-end (FQCN playbooks, fixed accounts, environment-variable inputs); proving it against further consumers happens by revision, not by draft status.

# RFC-006: Provisioning

Status: Accepted

Provisioning has a single purpose: to produce a host that is ready for baseline convergence — a supported Ubuntu installation, reachable over SSH by the baseline identities.

There is no golden image. Hosts start from the provider's official Ubuntu LTS image and are shaped from there; nothing is baked or snapshotted. VMs are created and destroyed with provider-native CLIs, not IaC tooling.

## First Boot

Provider user-data drives cloud-init at first boot to:

* create both baseline accounts — `ansible` and `sysadmin` — with their authorized keys and passwordless sudo, so the host is reachable by its intended identities immediately;
* lay down the baseline sshd drop-in;
* run a full package upgrade (first boot is the ideal moment — the box is empty) and reboot unconditionally, activating any new kernel and doubling as a smoke test: converge can only connect afterward if the host came back with working SSH.

The provider bootstrap identity remains usable through first boot as a debug path, until retirement (RFC-004: Identity and Trust).

## One Source, Two Moments

The Ansible roles are the single source of truth for everything cloud-init applies. The user-data is rendered from the same sources the roles own, so the two moments cannot diverge — and the first converge is therefore a no-op for accounts and SSH policy, doing new work only for the converge-only baseline controls.

What "the same" requires is per-module. State-based modules compare system state, so cloud-init and the roles only need to produce the same end state for accounts and keys. File-shaped controls are checksum-compared, so they must share bytes. Exactly two controls are file-shaped: the sshd drop-in, which the user-data renderer reads directly from the role-owned file, and the per-account sudoers rules, which the renderer duplicates byte-for-byte and keeps in lockstep with the role by explicit discipline — the rule is one line, and a shared source file would cost more than it protects. cloud-init's `sudo:` shortcut is deliberately not used: it writes a combined sudoers file the roles do not manage, which would surface as permanent drift.

## Hosts Not Born Here: Adoption

Provisioning, as this RFC defines it, is cloud provisioning: provider user-data driving cloud-init at first boot. Hosts that never passed through it — bare-metal machines installed by whatever means, servers already running workloads — are not provisioned into the baseline; they are adopted into it.

Adoption is a genuinely different problem, because it starts from a host whose state is unknown rather than empty. It must first discover what exists, then decide per finding whether to overwrite, coexist, or refuse and defer to a human. Those semantics are RFC-007: Adoption.

Install automation itself — how an operator gets Ubuntu onto bare metal, with Ubuntu Autoinstall or anything else — is deliberately outside this collection's concern. However a host was installed, it enters the baseline through adoption.

## Why cloud-init — a Reversal

The architecture that preceded this collection provisioned hosts bare and initialized them over SSH from the operator's workstation, deliberately excluding cloud-init. Two findings reversed that. First, initialization over SSH generates a burst of new port-22 connections that a scanning IPS on the operator's network reads as a port scan, silently dropping packets mid-initialization (see `docs/notes/ucg-fibre-ips-ssh-blocking.md`). Second, the one-source-two-moments discipline dissolved the original objection to cloud-init — that it would create a second, diverging definition of the baseline. With both findings in hand, first-boot provisioning became strictly better: no initialization SSH burst, and a host that is born conformant.

## Scope

This RFC defines the provisioning architecture and its division of labor with convergence.

It does not define the baseline (RFC-003: Baseline Contents), convergence semantics (RFC-008: Convergence), or the rendering implementation (the guides and `collection/scripts/`).

## Revisions

Initial version. Supersedes the prototype-era provisioning architecture, which excluded cloud-init.

Clarified the byte-identity mechanics: the sshd drop-in is read from the role-owned file; the sudoers rules are lockstep duplicates, not a shared source.

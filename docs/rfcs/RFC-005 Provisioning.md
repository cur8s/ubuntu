RFC-005: Provisioning

Status: Accepted

Provisioning has a single purpose: to produce a host that is ready for baseline convergence — a supported Ubuntu installation, reachable over SSH by the baseline identities.

There is no golden image. Hosts start from the provider's official Ubuntu LTS image and are shaped from there; nothing is baked or snapshotted. VMs are created and destroyed with provider-native CLIs, not IaC tooling.

**First Boot**

Provider user-data drives cloud-init at first boot to:

* create both baseline accounts — `ansible` and `sysadmin` — with their authorized keys and passwordless sudo, so the host is reachable by its intended identities immediately;
* lay down the baseline sshd drop-in;
* run a full package upgrade (first boot is the ideal moment — the box is empty) and reboot unconditionally, activating any new kernel and doubling as a smoke test: converge can only connect afterward if the host came back with working SSH.

The provider bootstrap identity remains usable through first boot as a debug path, until retirement (RFC-004: Identity and Trust).

**One Source, Two Moments**

The Ansible roles are the single source of truth for everything cloud-init applies. The user-data is rendered from the same sources the roles own, so the two moments cannot diverge — and the first converge is therefore a no-op for accounts and SSH policy, doing new work only for the converge-only floor controls.

What "the same" requires is per-module. State-based modules compare system state, so cloud-init and the roles only need to produce the same end state for accounts and keys. File-shaped controls are checksum-compared, so they must share bytes: exactly two files — the sshd drop-in and the per-account sudoers rules — are rendered into user-data from the role-owned sources. cloud-init's `sudo:` shortcut is deliberately not used: it writes a combined sudoers file the roles do not manage, which would surface as permanent drift.

**Bare Metal**

Bare-metal hosts use Ubuntu Autoinstall, nesting the same cloud-config under `autoinstall.user-data` and seeding it through the NoCloud datasource. The host that emerges is the same host cloud provisioning produces.

**Why cloud-init — a Reversal**

The architecture that preceded this collection provisioned hosts bare and initialized them over SSH from the operator's workstation, deliberately excluding cloud-init. Two findings reversed that. First, initialization over SSH generates a burst of new port-22 connections that a scanning IPS on the operator's network reads as a port scan, silently dropping packets mid-initialization (see `docs/notes/ucg-fibre-ips-ssh-blocking.md`). Second, the one-source-two-moments discipline dissolved the original objection to cloud-init — that it would create a second, diverging definition of the baseline. With both findings in hand, first-boot provisioning became strictly better: no initialization SSH burst, and a host that is born conformant.

**Scope**

This RFC defines the provisioning architecture and its division of labor with convergence.

It does not define the floor (RFC-003: Floor Contents), convergence semantics (RFC-006: Convergence), or the rendering implementation (the operations manual and `playbooks/cloud-init/`).

**Revisions**

Initial version. Supersedes the prototype-era provisioning architecture, which excluded cloud-init.

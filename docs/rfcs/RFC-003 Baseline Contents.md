# RFC-003: Baseline Contents

Status: Accepted

The baseline is intentionally small. A host conforms to it when the following hold.

**Access accounts.** The fixed `ansible` and `sysadmin` accounts exist with locked passwords, their authorized ed25519 keys, and passwordless sudo, as defined by RFC-004: Identity and Trust.

**OpenSSH policy.** The baseline sshd drop-in is in force: public-key authentication only, password and keyboard-interactive authentication disabled, authorized keys read from `.ssh/authorized_keys` alone (the deprecated `authorized_keys2` fallback is disabled — one less place a door can hide), no root password login, X11 forwarding disabled, idle-session keepalive. Root public-key login remains available only as the provider bootstrap path, until bootstrap retirement (RFC-004).

**Automatic security updates.** unattended-upgrades applies Ubuntu security updates automatically, and reboots are never automatic: a reboot is a deliberate operator or converge action, never a surprise from a background daemon. This pin is kept even though it currently matches the upstream default, because a silently flipped default here means unplanned production reboots — the one silent change with real blast radius.

**Persistent journald log capture.** The journal survives reboots: `Storage=persistent` is pinned. Stock `Storage=auto` persists only when `/var/log/journal` happens to exist, which is true on some provider images and not others; the pin makes the guarantee unconditional. Journal size limits, log forwarding, and rsyslog stay at distro defaults.

## Excluded From the Baseline

Time synchronization — trusted to distro and provider defaults. `systemd-timesyncd` ships installed, enabled, and syncing on every Ubuntu cloud image, and providers supply time sources. Pinning the mechanism would uninstall chrony from under a layer that legitimately wants it: the baseline fighting a layer. Revisit with a mechanism-agnostic assert on the first real clock incident.

auditd — the baseline's attribution contract is role-level (RFC-004); per-person forensics belong to the access layer. Audit rulesets require curation, generate heavy volume on container hosts, and add per-syscall overhead: they fail the inclusion test. A compliance layer may add auditd; the baseline does not fight it.

Kernel and sysctl tuning — layered. Knobs such as `ip_forward`, namespaces, and BPF must remain settable by layers like k3s; immovable hardening would break them.

Host firewall (ufw) — layered. Firewall policy is role-specific, and a wrong rule locks the operator out.

fail2ban — key-only SSH makes brute force moot, and a self-banning daemon is a self-lockout risk.

Network perimeter — a provider or use-case concern, layered as needed.

## Scope

This RFC enumerates the baseline. It accrues a revision whenever a control enters or leaves.

It does not define the inclusion test or role-authoring doctrine (RFC-002: Baseline Doctrine), the identity model (RFC-004: Identity and Trust), or how the controls are implemented.

## Revisions

Initial version. Records the baseline as first verified end-to-end: accounts, OpenSSH policy, unattended-upgrades, journald persistence. Time synchronization was implemented, verified, and then deliberately removed in favor of trusting defaults.

# journald role

This role owns the baseline audit/log-capture posture for Ubuntu hosts:
**the systemd journal persists across reboots**.

It asserts the Ubuntu 24.04 default rather than replacing it. The cloud image
already keeps the journal on disk (`Storage=auto` with `/var/log/journal`
present); this role pins that posture explicitly
(`/etc/systemd/journald.conf.d/10-ubuntu-baseline.conf` with
`Storage=persistent`), ensures journald is running, and asserts journal files
actually exist on disk. On a healthy default image every task is a no-op.

There is deliberately no repair branch for a deleted `/var/log/journal`.
Tested on a droplet (2026-07-02): journald notices the deletion on its next
write ("Journal file has been deleted, rotating") and recreates the tree
within seconds, so converge can never observe the missing-dir state on a live
host. One caveat from that test: the self-recreated directory comes back as
`root:root 0755` instead of `root:systemd-journal` setgid+ACL, which degrades
journal access for non-root members of `adm`/`systemd-journal` until the next
boot (`systemd-tmpfiles-setup` reapplies the attributes). Immediate manual
remediation: `sudo systemd-tmpfiles --create --prefix=/var/log/journal`.

Design decisions (RFC-001 §7, §9):

- **journald, not auditd.** The floor's attribution contract is role-level
  (automation vs. human) with *what/when/why* coming from git + converge
  logs; per-person identity is the access layer's job (Tailscale). Syscall
  auditing (`auditd` + rules) duplicates neither cheaply: it needs curated
  rulesets, generates heavy volume on busy/container hosts (k3s), and adds
  per-syscall overhead — it fails the floor test ("cannot break arbitrary
  future workloads") and belongs in a use-case/compliance layer, which this
  role does not fight.
- **Size limits stay on systemd defaults** (10% of the filesystem, capped at
  4G, oldest entries rotated out) — self-bounding on any disk size, so the
  journal can never fill a host.
- **rsyslog is left alone.** Images that ship it (DigitalOcean's does) keep
  their classic text logs (`/var/log/auth.log`); images without it lose
  nothing the baseline relies on.

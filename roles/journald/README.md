# journald role

This role owns the baseline audit/log-capture posture for Ubuntu hosts:
**the systemd journal persists across reboots**.

It pins one setting off the stock config: `Storage=persistent`
(`/etc/systemd/journald.conf.d/10-ubuntu-baseline.conf`). Stock `Storage=auto`
persists only when `/var/log/journal` happens to exist — true on the
DigitalOcean 24.04 image, not guaranteed on minimal or other-provider images,
where logs silently live in RAM and vanish at reboot. `persistent` makes the
guarantee unconditional. Everything else (size caps — 10% of the filesystem,
4G max — forwarding, rsyslog) stays distro default: nothing declared, nothing
to maintain.

There are deliberately no verification or repair tasks. A drift experiment on
a droplet (2026-07-02, `rm -rf /var/log/journal`) showed journald self-heals:
it notices on its next log write ("Journal file has been deleted, rotating")
and recreates the tree within seconds, so a converge-time existence check can
never observe the broken state — every converge generates journal writes
before any probe could run. One caveat from that test: the self-recreated
directory comes back `root:root 0755` instead of `root:systemd-journal`
setgid+ACL, degrading journal access for non-root `adm`/`systemd-journal`
members until the next boot reapplies tmpfiles rules. Immediate manual
remediation: `sudo systemd-tmpfiles --create --prefix=/var/log/journal`.

Design decisions (RFC-002: Floor Doctrine, RFC-003: Floor Contents, RFC-004: Identity and Trust):

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

# unattended_upgrades role

Automatic security updates — the baseline control that keeps every host
patched without an operator in the loop (RFC-003: Baseline Contents).

Pins:

- `/etc/apt/apt.conf.d/20auto-upgrades` — daily package-list refresh and
  unattended-upgrade runs.
- `/etc/apt/apt.conf.d/52-baseline-unattended-upgrades` —
  `Automatic-Reboot "false"`: a reboot is a deliberate operator or converge
  action, never a background surprise. The higher-numbered drop-in wins
  over the distro's `50unattended-upgrades`.
- `apt-daily.timer` and `apt-daily-upgrade.timer` enabled and active.

Both pinned values currently match upstream defaults, and the pins are
kept anyway — RFC-002's doctrine permits pinning a default that must hold
unconditionally, and these are the two defaults whose silent flip has real
blast radius: unpatched hosts, or surprise production reboots.
Security-only update origins are already the distro default and are
trusted, not pinned.

Non-security updates are deliberately out of scope: apply them with the
operator-invoked `cur8s.ubuntu.patch` playbook, and activate pending
kernels through the validating reboot path (`cur8s.ubuntu.validate_reboot`).

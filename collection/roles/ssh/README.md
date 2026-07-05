# ssh role

This role owns the baseline OpenSSH daemon policy for Ubuntu hosts.

It does not install `openssh-server` — doctrine, not omission (RFC-002:
Baseline Doctrine): every Ubuntu server image ships sshd, and converge can
only run against a host that is already reachable over SSH, so the
package's presence is a precondition of converge, not a state this role
could meaningfully declare.

The role uses an `sshd_config.d` drop-in instead of editing
`/etc/ssh/sshd_config` in place: write the file you own, validate it with
`sshd -t` before install, ensure `ssh.socket` is enabled and listening,
reload on change, and assert the effective daemon configuration with
`sshd -T`. The same drop-in file is embedded into first-boot user-data by
the cloud-init renderer (RFC-006: Provisioning), which is why the first
converge is a no-op for SSH policy.

Fixed policy (`files/10-ubuntu-baseline.conf`):

- password authentication disabled
- authorized keys read from `.ssh/authorized_keys` only — the legacy
  `authorized_keys2` fallback (deprecated since 2001, honored by stock
  sshd ever since) is disabled, so key material outside the one known
  file opens nothing on a conformant host. The access-surface report and
  the lock still watch and clear both paths: adoption meets hosts this
  pin does not govern yet, and key material outlives configuration.
- keyboard-interactive authentication disabled
- public key authentication enabled
- root password login disabled; root public-key login remains available as
  the provider bootstrap path until retirement (RFC-004: Identity and Trust)
- X11 forwarding disabled
- idle client keepalive (300s interval, two missed replies disconnect)

# ssh role

This role owns the baseline OpenSSH daemon policy for Ubuntu hosts.

It intentionally does not install `openssh-server` yet. The current target is a
DigitalOcean Ubuntu image that is already reachable over SSH, so this role starts
by owning the daemon configuration and socket listener boot state.

The role uses an `sshd_config.d` drop-in instead of editing
`/etc/ssh/sshd_config` in place. That is the conventional Ansible approach when
the platform supports it: write the file you own, ensure `ssh.socket` is enabled
and listening, validate the config before installing, reload the service, and
assert the effective daemon configuration.

Current fixed policy:

- password authentication disabled
- keyboard-interactive authentication disabled
- public key authentication enabled
- root password login disabled; root public key login remains available for bootstrap recovery
- X11 forwarding disabled
- idle client keepalive configured

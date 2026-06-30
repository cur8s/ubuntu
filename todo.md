# TODO

Remaining work to bring the repository fully in line with the RFCs.

## Provisioning

- [ ] Add a cloud-init template for delivering the administrator SSH public key.
- [ ] Add a 1Password workflow for reading or rendering the administrator SSH public key.
- [ ] Update DigitalOcean test VM creation to use the intended cloud-init or provider metadata flow.
- [ ] Replace the temporary DigitalOcean SSH key generation/import workflow with the 1Password-backed public key workflow.
- [ ] Decide whether DigitalOcean SSH key import should remain supported for lab setup when the key is not already present in DigitalOcean.
- [ ] If DigitalOcean SSH key import remains supported, preserve the old behavior: look up the key by name, import the public key only when missing, and pass the resulting key ID to droplet creation.
- [ ] Preserve the cloud-init lab defaults when adding the new provisioning template: `disable_root: false`, `ssh_pwauth: false`, and `package_update: false`.
- [ ] Preserve the lab MOTD intent when useful: mark disposable test VMs as Cur8s Ubuntu bootstrap lab hosts.
- [ ] Add bare-metal Autoinstall assets.
- [ ] Add a NoCloud datasource template for bare-metal administrator key delivery.
- [ ] Document administrator key storage, rendering, rotation, and recovery.

## SSH Hardening Follow-up

The current Ansible baseline already disables SSH password authentication, disables keyboard-interactive SSH authentication, enables public key authentication, disables X11 forwarding, and allows root login only with keys for bootstrap and recovery.

The temporary bootstrap also configured these additional SSH settings:

```sshconfig
PermitRootLogin no
AllowTcpForwarding yes
ClientAliveInterval 300
ClientAliveCountMax 2
Port ${SSH_PORT}
```

- [ ] Add `ClientAliveInterval 300` to the Ansible SSH baseline.
- [ ] Add `ClientAliveCountMax 2` to the Ansible SSH baseline.
- [ ] Add `sshd -T` assertions for `clientaliveinterval 300` and `clientalivecountmax 2`.
- [ ] Defer `PermitRootLogin no` until Tailscale SSH and/or a non-root administrator account is implemented; otherwise bootstrap and recovery access may break.
- [ ] Do not add `Port ${SSH_PORT}` unless the baseline explicitly chooses non-standard SSH ports; it complicates Ansible, recovery, and network rules without much security value.
- [ ] Do not add `AllowTcpForwarding yes` as hardening; it is an explicit allowance and should wait for a forwarding policy decision.

## Management Network

- [ ] Join the host to Tailscale during baseline convergence.
- [ ] Decide how Tailscale auth keys are stored and passed, likely through 1Password.
- [ ] Enable Tailscale SSH.
- [ ] Use the temporary bootstrap behavior as the starting point: `TAILSCALE_UP_FLAGS` defaults to `--ssh`, then convergence runs `tailscale up --authkey "$TAILSCALE_AUTHKEY" ${TAILSCALE_UP_FLAGS}` when the host is not already connected.
- [ ] Make Tailscale join idempotent by checking `tailscale status` before requiring an auth key.
- [ ] Validate that the host is joined to the tailnet.
- [ ] Validate that Tailscale SSH is enabled.
- [ ] Decide how to enforce the Management Network as the exclusive administration path.

## Example Playbooks

- [ ] Add a Fail2ban example playbook.
- [ ] Configure the Fail2ban example with an SSH jail equivalent to the temporary `sshd-production.conf`: `[sshd]`, `enabled = true`, `backend = systemd`, `maxretry = 5`, `findtime = 10m`, and `bantime = 1h`.
- [ ] Install Fail2ban from Ubuntu packages.
- [ ] Validate that `fail2ban.service` is enabled and active in the Fail2ban example.
- [ ] Add a UFW example playbook.
- [ ] Configure the UFW example with default deny incoming and default allow outgoing.
- [ ] Make the UFW example allow explicit TCP ports, defaulting to `22/tcp`.
- [ ] Validate that UFW is active in the UFW example.
- [ ] Add mise tasks for the Fail2ban and UFW example playbooks.

## Baseline Verification

- [ ] Add a dedicated baseline verification playbook or mode.
- [ ] Use the temporary `ubuntu-check` script as source material for the first verification pass.
- [ ] Verify Ubuntu release conformance.
- [ ] Verify OpenSSH baseline policy.
- [ ] Verify the OpenSSH config drop-in exists.
- [ ] Verify unattended package maintenance.
- [ ] Verify UFW only in the optional UFW example, not in the baseline.
- [ ] Verify Fail2ban only in the optional Fail2ban example, not in the baseline.
- [ ] Verify Tailscale join state and Tailscale SSH state.
- [ ] Verify `tailscaled.service` is enabled.
- [ ] Verify osquery is installed for interactive use and not running as a daemon.
- [ ] Verify the osquery apt source exists and `osqueryi` is available.
- [ ] Verify Lynis is installed.
- [ ] Verify the CISOfy Lynis apt source exists and `lynis` is available.
- [ ] Produce a clear pass/fail baseline report.
- [ ] Consider adding a network-facing SSH probe.

## Operational Commands

- [ ] Add production-oriented mise tasks or another production host workflow.
- [ ] Add inventory or host targeting beyond the single DigitalOcean test VM.
- [ ] Decide whether to pin `ansible_python_interpreter=/usr/bin/python3` in inventory or mise tasks to avoid Ansible interpreter discovery warnings.
- [ ] Decide whether `test-vm-*` remains only the lab workflow.
- [ ] Record that the old repo sync/bootstrap/check flow is intentionally replaced by local Ansible-over-SSH.

## Documentation

- [ ] Add an operational guide for provisioning a new cloud VM.
- [ ] Add an operational guide for converging a provisioned host.
- [ ] Add an operational guide for reboot handling.
- [ ] Add an operational guide for installing optional examples such as Docker, PostgreSQL, and zot.
- [ ] Add a mapping from each RFC requirement to the implementation files that satisfy it.

## Policy Decisions

- [ ] Decide how strict the Management Network exclusivity rule should be before adding firewall or cloud firewall rules.
- [ ] Decide whether public SSH remains acceptable for bootstrap and recovery.
- [ ] Decide whether immediate package upgrades should remain part of every convergence run.
- [ ] Decide when RFC-007 should move from Draft to Accepted.

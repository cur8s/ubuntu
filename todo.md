# TODO

Remaining work to bring the repository fully in line with the RFCs.

Next groups to work on:

1. Initialize Host Workflow
2. SSH Hardening Policy

## Initialize Host Workflow

Create a fresh-host initialization path that turns a provider-created Ubuntu VM into a host with non-root SSH access.

- [ ] Run `mise run test-vm-init` against a fresh DigitalOcean test VM and fix any initialization issues.
- [ ] Prove `mise run test-vm-ssh-ansible` works.
- [ ] Prove `mise run test-vm-ssh-admin` works.
- [ ] Decide the next initialization step after SSH access is proven.
- [ ] After initialization is proven, switch `test-vm-converge` to run as `--user ansible --become`.
- [ ] Document administrator SSH key storage, rendering, rotation, and recovery.
- [ ] Replace the hard-coded DigitalOcean SSH key ID with lookup or verification against the 1Password-rendered administrator public key.
- [ ] Decide whether `test-vm-ssh` and Ansible commands should constrain SSH to the rendered administrator public key with `IdentitiesOnly yes`.
- [ ] Consider adding a network-facing SSH probe.
- [ ] Decide whether public SSH remains acceptable for bootstrap and recovery.
- [ ] Decide how to enforce the Management Network as the exclusive administration path.

## SSH Hardening Policy

Track remaining SSH hardening policy decisions.

The temporary bootstrap also configured these additional SSH settings that are not yet in the baseline:

```sshconfig
PermitRootLogin no
AllowTcpForwarding yes
Port ${SSH_PORT}
```

- [ ] Defer `PermitRootLogin no` until Tailscale SSH and/or a non-root administrator account is implemented; otherwise bootstrap and recovery access may break.
- [ ] Do not add `Port ${SSH_PORT}` unless the baseline explicitly chooses non-standard SSH ports; it complicates Ansible, recovery, and network rules without much security value.
- [ ] Do not add `AllowTcpForwarding yes` as hardening; it is an explicit allowance and should wait for a forwarding policy decision.

## Baseline Verification

Add a dedicated verification path once the baseline convergence behavior has settled.

- [ ] Add a dedicated baseline verification playbook or mode.
- [ ] Use the captured `ubuntu-check` behavior as source material for the first verification pass.
- [ ] Verify Ubuntu release conformance.
- [ ] Verify the administrator SSH public key is authorized.
- [ ] Verify OpenSSH baseline policy.
- [ ] Verify the OpenSSH config drop-in exists.
- [ ] Verify unattended package maintenance.
- [ ] Verify Tailscale join state and Tailscale SSH state.
- [ ] Verify `tailscaled.service` is enabled.
- [ ] Produce a clear pass/fail baseline report.
- [ ] Add an operational guide for converging a provisioned host.
- [ ] Add an operational guide for reboot handling.

## Optional Example Playbooks

Keep these outside the baseline while showing how to build on it.

- [ ] Add a Fail2ban example playbook.
- [ ] Install Fail2ban from Ubuntu packages.
- [ ] Configure the Fail2ban example with an SSH jail equivalent to the temporary `sshd-production.conf`: `[sshd]`, `enabled = true`, `backend = systemd`, `maxretry = 5`, `findtime = 10m`, and `bantime = 1h`.
- [ ] Validate that `fail2ban.service` is enabled and active in the Fail2ban example.
- [ ] Verify Fail2ban only in the optional Fail2ban example, not in the baseline.
- [ ] Add a UFW example playbook.
- [ ] Configure the UFW example with default deny incoming and default allow outgoing.
- [ ] Make the UFW example allow explicit TCP ports, defaulting to `22/tcp`.
- [ ] Validate that UFW is active in the UFW example.
- [ ] Verify UFW only in the optional UFW example, not in the baseline.
- [ ] Add mise tasks for the Fail2ban and UFW example playbooks.
- [ ] Add an operational guide for installing optional examples such as Docker, PostgreSQL, zot, osquery, and Lynis.

## Operational Shape And Documentation

Turn the lab workflow into a clearer operating model.

- [ ] Add inventory or host targeting beyond the single DigitalOcean test VM.
- [ ] Add production-oriented mise tasks or another production host workflow.
- [ ] Decide whether to pin `ansible_python_interpreter=/usr/bin/python3` in inventory or mise tasks to avoid Ansible interpreter discovery warnings.
- [ ] Decide whether `test-vm-*` remains only the lab workflow.
- [ ] Record that the old repo sync/bootstrap/check flow is intentionally replaced by local Ansible-over-SSH.
- [ ] Add a mapping from each RFC requirement to the implementation files that satisfy it.
- [ ] Decide whether immediate package upgrades should remain part of every convergence run.
- [ ] Decide when RFC-007 should move from Draft to Accepted.

## Bare-metal Provisioning

Add bare-metal provisioning after the cloud VM path is proven.

- [ ] Add bare-metal Autoinstall assets.
- [ ] Decide whether Autoinstall alone is sufficient for bare-metal administrator key delivery.
- [ ] Add a NoCloud datasource template only if Autoinstall cannot cover the bare-metal administrator key workflow.

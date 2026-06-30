# TODO

Remaining work to bring the repository fully in line with the RFCs.

Next groups to work on:

1. Phase 1: Provisioning And Admin Access
2. Phase 2: Tailscale Join And Management Path

## Phase 1: Provisioning And Admin Access

Define how a new machine receives trusted administrator SSH access before Ansible convergence starts.

- [ ] Add a 1Password workflow for reading or rendering the administrator SSH public key.
- [ ] Add a cloud-init template for delivering the administrator SSH public key.
- [ ] Update DigitalOcean test VM creation to use the intended cloud-init or provider metadata flow.
- [ ] Replace the temporary DigitalOcean SSH key generation/import workflow with the 1Password-backed public key workflow.
- [ ] Decide whether DigitalOcean SSH key import should remain supported for lab setup when the key is not already present in DigitalOcean.
- [ ] If DigitalOcean SSH key import remains supported, preserve the old behavior: look up the key by name, import the public key only when missing, and pass the resulting key ID to droplet creation.
- [ ] Preserve the cloud-init lab defaults when adding the new provisioning template: `disable_root: false`, `ssh_pwauth: false`, and `package_update: false`.
- [ ] Preserve the lab MOTD intent when useful: mark disposable test VMs as Cur8s Ubuntu bootstrap lab hosts.
- [ ] Document administrator key storage, rendering, rotation, and recovery.
- [ ] Add an operational guide for provisioning a new cloud VM.

## Phase 2: Tailscale Join And Management Path

Move from public bootstrap access toward the intended private management network.

- [ ] Decide how Tailscale auth keys are stored and passed, likely through 1Password.
- [ ] Join the host to Tailscale during baseline convergence.
- [ ] Use the temporary bootstrap behavior as the starting point: `TAILSCALE_UP_FLAGS` defaults to `--ssh`, then convergence runs `tailscale up --authkey "$TAILSCALE_AUTHKEY" ${TAILSCALE_UP_FLAGS}` when the host is not already connected.
- [ ] Make Tailscale join idempotent by checking `tailscale status` before requiring an auth key.
- [ ] Enable Tailscale SSH.
- [ ] Validate that the host is joined to the tailnet.
- [ ] Validate that Tailscale SSH is enabled.
- [ ] Decide whether public SSH remains acceptable for bootstrap and recovery.
- [ ] Decide how to enforce the Management Network as the exclusive administration path.

## Phase 3: SSH Hardening Follow-up

Tighten the SSH baseline after the management path is clear.

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
- [ ] Consider adding a network-facing SSH probe.

## Phase 4: Baseline Verification

Add a dedicated verification path once the baseline convergence behavior has settled.

- [ ] Add a dedicated baseline verification playbook or mode.
- [ ] Use the captured `ubuntu-check` behavior as source material for the first verification pass.
- [ ] Verify Ubuntu release conformance.
- [ ] Verify OpenSSH baseline policy.
- [ ] Verify the OpenSSH config drop-in exists.
- [ ] Verify unattended package maintenance.
- [ ] Verify Tailscale join state and Tailscale SSH state.
- [ ] Verify `tailscaled.service` is enabled.
- [ ] Verify osquery is installed for interactive use and not running as a daemon.
- [ ] Verify the osquery apt source exists and `osqueryi` is available.
- [ ] Verify Lynis is installed.
- [ ] Verify the CISOfy Lynis apt source exists and `lynis` is available.
- [ ] Produce a clear pass/fail baseline report.
- [ ] Add an operational guide for converging a provisioned host.
- [ ] Add an operational guide for reboot handling.

## Phase 5: Optional Example Playbooks

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
- [ ] Add an operational guide for installing optional examples such as Docker, PostgreSQL, and zot.

## Phase 6: Operational Shape And Documentation

Turn the lab workflow into a clearer operating model.

- [ ] Add inventory or host targeting beyond the single DigitalOcean test VM.
- [ ] Add production-oriented mise tasks or another production host workflow.
- [ ] Decide whether to pin `ansible_python_interpreter=/usr/bin/python3` in inventory or mise tasks to avoid Ansible interpreter discovery warnings.
- [ ] Decide whether `test-vm-*` remains only the lab workflow.
- [ ] Record that the old repo sync/bootstrap/check flow is intentionally replaced by local Ansible-over-SSH.
- [ ] Add a mapping from each RFC requirement to the implementation files that satisfy it.
- [ ] Decide whether immediate package upgrades should remain part of every convergence run.
- [ ] Decide when RFC-007 should move from Draft to Accepted.

## Phase 7: Bare-metal Provisioning

Add bare-metal provisioning after the cloud VM path is proven.

- [ ] Add bare-metal Autoinstall assets.
- [ ] Add a NoCloud datasource template for bare-metal administrator key delivery.

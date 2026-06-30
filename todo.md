# TODO

Remaining work to bring the repository fully in line with the RFCs.

Next groups to work on:

1. Phase 2: Tailscale Join And Management Path
2. Phase 3: SSH Trust And Hardening Follow-up

## Phase 1: Provisioning And Admin Access

Define how a new machine receives trusted administrator SSH access before Ansible convergence starts.

- [x] Add a 1Password workflow for reading or rendering the administrator SSH public key.
- [x] Update DigitalOcean test VM creation to use provider SSH key metadata for initial reachability.
- [x] Add the 1Password-rendered administrator public key workflow for convergence.
- [x] Decide whether DigitalOcean SSH key import should remain supported for lab setup when the key is not already present in DigitalOcean.
- [x] Add an operational guide for provisioning a new cloud VM.
- [x] Enforce the administrator SSH public key during baseline convergence.

## Phase 2: Tailscale Join And Management Path

Move from public bootstrap access toward the intended private management network.

- [x] Decide how Tailscale auth keys are stored and passed: the reusable auth key lives in 1Password and is read into a process-local `TAILSCALE_AUTHKEY` environment variable by the mise converge task.
- [x] Join the host to Tailscale during baseline convergence.
- [x] Use the temporary bootstrap behavior as the starting point: convergence runs `tailscale up --auth-key "$TAILSCALE_AUTHKEY" --ssh --accept-dns=false` when the host is not already connected.
- [x] Make Tailscale join idempotent by checking `tailscale status --json` before requiring an auth key.
- [x] Enable Tailscale SSH.
- [x] Validate that the host is joined to the tailnet.
- [x] Validate that Tailscale SSH is enabled.
- [ ] Decide whether public SSH remains acceptable for bootstrap and recovery.
- [ ] Decide how to enforce the Management Network as the exclusive administration path.

## Phase 3: SSH Trust And Hardening Follow-up

Track completed SSH trust work and the remaining SSH hardening/key-handling work.

Completed SSH work:

- [x] Use provider SSH key metadata for initial cloud VM reachability.
- [x] Render the administrator SSH public key from 1Password for convergence.
- [x] Enforce the administrator SSH public key in root's `authorized_keys` during baseline convergence.
- [x] Install and validate OpenSSH server during baseline convergence.
- [x] Manage the baseline OpenSSH drop-in at `/etc/ssh/sshd_config.d/10-cur8s-baseline.conf`.
- [x] Disable SSH password authentication.
- [x] Disable keyboard-interactive SSH authentication.
- [x] Enable SSH public key authentication.
- [x] Disable X11 forwarding.
- [x] Allow root SSH only with keys for bootstrap and recovery.
- [x] Validate OpenSSH syntax before reload.
- [x] Assert the effective OpenSSH policy with `sshd -T`.

Remaining SSH work:

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
- [ ] Replace the hard-coded DigitalOcean SSH key ID with lookup or verification against the 1Password-rendered administrator public key.
- [ ] Decide whether `test-vm-ssh` and Ansible commands should constrain SSH to the rendered administrator public key with `IdentitiesOnly yes`.
- [ ] Document administrator SSH key storage, rendering, rotation, and recovery.
- [ ] Defer `PermitRootLogin no` until Tailscale SSH and/or a non-root administrator account is implemented; otherwise bootstrap and recovery access may break.
- [ ] Do not add `Port ${SSH_PORT}` unless the baseline explicitly chooses non-standard SSH ports; it complicates Ansible, recovery, and network rules without much security value.
- [ ] Do not add `AllowTcpForwarding yes` as hardening; it is an explicit allowance and should wait for a forwarding policy decision.
- [ ] Consider adding a network-facing SSH probe.

## Phase 4: Baseline Verification

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
- [ ] Decide whether Autoinstall alone is sufficient for bare-metal administrator key delivery.
- [ ] Add a NoCloud datasource template only if Autoinstall cannot cover the bare-metal administrator key workflow.

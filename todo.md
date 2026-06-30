# TODO

Remaining work to bring the repository fully in line with the RFCs.

## Provisioning

- [ ] Add a cloud-init template for delivering the administrator SSH public key.
- [ ] Add a 1Password workflow for reading or rendering the administrator SSH public key.
- [ ] Update DigitalOcean test VM creation to use the intended cloud-init or provider metadata flow.
- [ ] Add bare-metal Autoinstall assets.
- [ ] Add a NoCloud datasource template for bare-metal administrator key delivery.
- [ ] Document administrator key storage, rendering, rotation, and recovery.

## Baseline Preconditions

- [ ] Assert that the target host is Ubuntu 24.04 LTS.
- [ ] Assert that the Ubuntu codename is `noble`.
- [ ] Fail early on unsupported Ubuntu releases.
- [ ] Decide whether to assert supported CPU architectures before adding third-party package repositories.

## Management Network

- [ ] Join the host to Tailscale during baseline convergence.
- [ ] Decide how Tailscale auth keys are stored and passed, likely through 1Password.
- [ ] Enable Tailscale SSH.
- [ ] Validate that the host is joined to the tailnet.
- [ ] Validate that Tailscale SSH is enabled.
- [ ] Decide how to enforce the Management Network as the exclusive administration path.

## Baseline Verification

- [ ] Add a dedicated baseline verification playbook or mode.
- [ ] Verify Ubuntu release conformance.
- [ ] Verify OpenSSH baseline policy.
- [ ] Verify unattended package maintenance.
- [ ] Verify Tailscale join state and Tailscale SSH state.
- [ ] Verify osquery is installed for interactive use and not running as a daemon.
- [ ] Verify Lynis is installed.
- [ ] Produce a clear pass/fail baseline report.
- [ ] Consider adding a network-facing SSH probe.

## Operational Commands

- [ ] Add production-oriented mise tasks or another production host workflow.
- [ ] Add inventory or host targeting beyond the single DigitalOcean test VM.
- [ ] Decide whether `test-vm-*` remains only the lab workflow.

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

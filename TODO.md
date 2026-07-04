# TODO — cur8s.ubuntu

Open work only, in priority order. `[~]` in progress · `[ ]` not started.
Completed work lives in git history and the RFC Revisions blocks.

## 1. Key rotation (before the release)
- [ ] Design and build the rotation path for the baseline account keys: new key in 1Password → propagate → prove both accounts → remove the old key. The removal step is the open decision: converge is deliberately non-exclusive and never removes access (RFC-005: Accounts and Access), so rotation either becomes a standalone deliberate playbook (the lock_accounts pattern — prove the new door, then close the old key) or unparks exclusive-key enforcement via an RFC-005/RFC-008 revision. Until it lands, a rotated-out key lingers as a live door: `report_access` shows it as a foreign key, and the adoption assessment refuses on it by design. RFC-004's scope currently excludes rotation procedures — that line changes with this item.

## 2. First release (RFC-010; after rotation)
- [ ] Cut `v24.4.0` once rotation lands: bump nothing (version already `24.4.0`), tag, `git push origin main --tags`, then pin the tag in `examples/requirements.yml` and the manual's install snippets.

## 3. Multi-provider verification (post-release; gated on actual need)
- [ ] Verify the baseline on AWS, Azure, and GCP — today it is verified on DigitalOcean only, and the QEMU harness covers the provider-neutral half (the render on pristine Ubuntu). Per provider: a harness task family (key injection + create, provider CLI), the provider's bootstrap user as the `LOCK_ACCOUNTS` target, then the standard steel thread + validate_reboot. Known risk points to watch: provider images' own cloud-init/sshd drop-ins conflicting with ours (the `sshd -T` asserts will catch it), and Azure's provisioning agent vs the first-boot `power_state` reboot. Expected: near-zero collection changes; mostly harness. Do not start until a real workload needs one of these providers.

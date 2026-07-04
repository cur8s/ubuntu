# TODO — cur8s.ubuntu

Open work only, in priority order. `[~]` in progress · `[ ]` not started.
Completed work lives in git history and the RFC Revisions blocks.

## 1. First release (RFC-010)
- [ ] Cut `v24.4.0`: bump nothing (version already `24.4.0`), tag, `git push origin main --tags`, then pin the tag in `examples/requirements.yml` and the manual's install snippets.

## 2. Multi-provider verification (post-release; gated on actual need)
- [ ] Verify the baseline on AWS, Azure, and GCP — today it is verified on DigitalOcean only, and the QEMU harness covers the provider-neutral half (the render on pristine Ubuntu). Per provider: a harness task family (key injection + create, provider CLI), the provider's bootstrap user as the `LOCK_ACCOUNTS` target, then the standard steel thread + validate_reboot. Known risk points to watch: provider images' own cloud-init/sshd drop-ins conflicting with ours (the `sshd -T` asserts will catch it), and Azure's provisioning agent vs the first-boot `power_state` reboot. Expected: near-zero collection changes; mostly harness. Do not start until a real workload needs one of these providers.

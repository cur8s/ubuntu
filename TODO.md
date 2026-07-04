# TODO — cur8s.ubuntu

Open work only, in priority order. `[~]` in progress · `[ ]` not started.
Completed work lives in git history and the RFC Revisions blocks.

## 1. Server adoption
- [ ] Bring existing Ubuntu 24.04 hosts under the baseline — the generic on-ramp for every host not born via cloud provisioning (RFC-006): bare metal however installed, servers already running workloads. Start from the design in `docs/notes/adopting-existing-servers.md` (re-validate against current code at pickup) and extend it with the discovery semantics: a read-only assessment of what exists, then a per-finding policy — overwrite, coexist, or refuse and ask a human — which is the core design axis. Local test bed: a QEMU cloud-image VM booted without the baseline user-data as the "existing server" (the harness for that is small; the existing qemu family is the template). Includes the deferred key-drift-reversion and retirement sudo-group questions recorded in the note.

## 2. First release (RFC-009; after adoption)
- [ ] Cut `v24.4.0` once adoption lands: bump nothing (version already `24.4.0`), tag, `git push origin main --tags`, then pin the tag in `examples/requirements.yml` and the manual's install snippets.

## 3. Multi-provider verification (post-release; gated on actual need)
- [ ] Verify the baseline on AWS, Azure, and GCP — today it is verified on DigitalOcean only, and the QEMU harness covers the provider-neutral half (the render on pristine Ubuntu). Per provider: a harness task family (key injection + create, provider CLI), the provider's bootstrap user as the `LOCK_ACCOUNTS` target, then the standard steel thread + validate_reboot. Known risk points to watch: provider images' own cloud-init/sshd drop-ins conflicting with ours (the `sshd -T` asserts will catch it), and Azure's provisioning agent vs the first-boot `power_state` reboot. Expected: near-zero collection changes; mostly harness. Do not start until a real workload needs one of these providers.

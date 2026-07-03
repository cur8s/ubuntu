# TODO — cur8s.ubuntu

Open work only, in priority order. `[~]` in progress · `[ ]` not started.
Completed work lives in git history and the RFC Revisions blocks.

## 1. Bare-metal autoinstall (builds on the QEMU harness)
- [ ] Simulate a bare-metal install: live-server ISO + blank disk, autoinstall seed nesting the same cloud-config under `autoinstall.user-data` (RFC-005), the install-then-reboot two-boot lifecycle, serial-console debugging, long timeouts. End state: the same steel thread proven against the *installed* disk. Kept separate from the cloud-image harness (`mise-tasks/qemu/`, done) so installer failures debug as installer failures, not harness failures.

## 2. Server adoption (after autoinstall, per sequencing decision)
- [ ] Implement adoption of existing Ubuntu 24.04 servers (bare metal without the baseline accounts): read-only `adoptable` assessment + additive `adopt` playbook, per the design in `docs/notes/adopting-existing-servers.md`. Its hard dependency (the QEMU harness as the local "existing server" test bed) is done; sitting after #1 is a scheduling choice. Re-validate the design against the code when picked up; includes the deferred key-drift-reversion and retirement sudo-group questions recorded there.

## 3. First release (RFC-008; after adoption)
- [ ] Cut `v24.4.0` once adoption lands: bump nothing (version already `24.4.0`), tag, `git push origin main --tags`, then pin the tag in `examples/requirements.yml` and the manual's install snippets.

## 4. Multi-provider verification (post-release; gated on actual need)
- [ ] Verify the baseline on AWS, Azure, and GCP — today it is verified on DigitalOcean only, and the QEMU harness covers the provider-neutral half (the render on pristine Ubuntu). Per provider: a harness task family (key injection + create, provider CLI), the provider's bootstrap user as `BOOTSTRAP_USER`, then the standard steel thread + validate_reboot. Known risk points to watch: provider images' own cloud-init/sshd drop-ins conflicting with ours (the `sshd -T` asserts will catch it), and Azure's provisioning agent vs the first-boot `power_state` reboot. Expected: near-zero collection changes; mostly harness. Do not start until a real workload needs one of these providers.

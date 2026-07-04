# TODO — cur8s.ubuntu

Open work only, in priority order. `[~]` in progress · `[ ]` not started.
Completed work lives in git history and the RFC Revisions blocks.

## 1. Docs completeness and the user guide (pre-release review, first on purpose)
- [ ] Audit every doc for completeness and accuracy against the current code: the operations manual, README, role READMEs, `examples/README.md`. The centerpiece: a good start-to-finish user guide that the operator will personally validate by following it cold — decide whether the manual already is that guide or a dedicated guide is needed. Docs go first deliberately: edge cases discovered while documenting may still change code freely, because the code reviews come later.

## 2. RFC review and approval round
- [ ] Read all twelve RFCs (000–011) end to end and approve each. Check the reading-order arc holds, cross-references are right, statuses are honest, and nothing normative contradicts the code as built. Amendments land as part of this item.

## 3. Playbook review
- [ ] Read every collection playbook, shared task file, and role with fresh eyes; surface and resolve any concerns (structure, naming, failure modes, output readability). Code changes are unrestricted here — that freedom is why this comes after docs.

## 4. mise harness review
- [ ] Review the task grammar end to end: task names and descriptions, `lib.sh`, hidden plumbing, the cheat sheet, next-hints, and whether the workflows still read plainly after everything added since the grammar was set.

## 5. QEMU lab review
- [ ] Review how the lab does images, seeds, boot, wait, and teardown — cross-checked against the explore-qemu learnings — and confirm the vanilla-specimen flow reads as clearly as the baseline flow.

## 6. Contributor guide and agent entry points
- [ ] Write the contributor guide (how to work in this repo: RFC-first workflow, task grammar, test contracts, doc taxonomy), then link `AGENTS.md` and `CLAUDE.md` to it with `ln -s` so humans and coding agents share one entry point. Last of the reviews on purpose: it documents the reviewed, settled state.

## 7. First release (RFC-010; after the review pass)
- [ ] Cut `v24.4.0`: bump nothing (version already `24.4.0`), tag, `git push origin main --tags`, then pin the tag in `examples/requirements.yml` and the manual's install snippets.

## 8. Multi-provider verification (post-release; gated on actual need)
- [ ] Verify the baseline on AWS, Azure, and GCP — today it is verified on DigitalOcean only, and the QEMU harness covers the provider-neutral half (the render on pristine Ubuntu). Per provider: a harness task family (key injection + create, provider CLI), the provider's bootstrap user as the `LOCK_ACCOUNTS` target, then the standard steel thread + validate_reboot. Known risk points to watch: provider images' own cloud-init/sshd drop-ins conflicting with ours (the `sshd -T` asserts will catch it), and Azure's provisioning agent vs the first-boot `power_state` reboot. Expected: near-zero collection changes; mostly harness. Do not start until a real workload needs one of these providers.

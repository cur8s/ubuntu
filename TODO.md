# TODO — cur8s.ubuntu

Open work only, in priority order. `[~]` in progress · `[ ]` not started.
Completed work lives in git history and the RFC Revisions blocks.
Ordering rule for the pre-release pass: every review that can change
code (playbooks, harness, lab) runs before the docs and RFC reads, so
the words are validated against the system as it will actually ship.

## 1. Playbook review (code first, on purpose)
- [ ] Read every collection playbook, shared task file, and role with fresh eyes; surface and resolve any concerns (structure, naming, failure modes, output readability). Code changes are unrestricted here — which is exactly why the code reviews precede the docs and RFC reads: what those describe will already be final.

## 2. mise harness review (code)
- [ ] Review the task grammar end to end: task names and descriptions, the import files (`mise-tasks/test/example-suite.sh`, the collection's lab scripts), hidden plumbing, the cheat sheet, next-hints, and whether the workflows still read plainly after everything added since the grammar was set.

## 3. QEMU lab review (code)
- [ ] Review how the lab does images, seeds, boot, wait, and teardown — cross-checked against the explore-qemu learnings — and confirm the rehearsal flows read as clearly as the baseline flow.
- [ ] Review the vendored-harness seam and the CI workflow (.github/workflows/ci.yml) that runs the same lab on amd64 KVM runners. The host-arch mechanics this item originally named (platform truth table, make_seed_iso, UEFI/SeaBIOS split) moved upstream into cur8s/qemu's qemu-vm.sh (vendored at mise-tasks/vendor/, pinned v0.3.1) — review the pin and the integration seam here; the mechanics are reviewed upstream.

## 4. Docs validation (after the code settles, on purpose)
- [~] The structure is done: the operations manual dissolved into `docs/guides/user-guide.md` (consumer lifecycle + runbooks) and `docs/guides/developer-guide.md` (repo iteration; `AGENTS.md` is the short agent-facing form, `CLAUDE.md` links to it). Remaining: the operator validates the user guide by following it cold against real hosts, audits both guides plus README and role READMEs for gaps, and fixes land as found. While in there: add the one missing lifecycle answer — how a host *leaves* the baseline (stop converging; nothing to uninstall, because the baseline stays near defaults). Docs are validated after the code reviews deliberately: by then every command and behavior the guides describe is final, so a cold read validates the real system instead of a moving one.

## 5. RFC review and approval round
- [ ] Read all twelve RFCs (000–011) end to end and approve each. Check the reading-order arc holds, cross-references are right, statuses are honest, and nothing normative contradicts the code as built — which by this point is settled. Amendments land as part of this item. (The three long-queued amendments — the C3 never-removes refinement in RFC-005/008, the RFC-009 coverage reword, and the RFC-002 ownership doctrine + RFC-005 report-scope boundary — landed 2026-07-07.)

## 6. First release (RFC-010; after the review pass)
- [ ] Release gate precondition (RFC-009; nothing in-repo enforces this anymore): the sandbox DigitalOcean harness (`sandbox/digital-ocean/`, copied from this repo at b0ba5ff) must pass `mise run test` against the release-candidate ref before tagging (the real-provider leg; CI already proves amd64 continuously). First proven against b0ba5ff on 2026-07-05; the harness follows the `reboot_and_verify` rename as of sandbox commit 7eb8275.
- [ ] Cut `v24.4.0`: bump nothing (version already `24.4.0`), tag, `git push origin main --tags`, then pin the tag: in the install snippets, in the examples' `requirements.yml` files (they ship `version: main` until a tag exists), and in the sandbox harness's `requirements.yml`.

## 7. Multi-provider verification (post-release; gated on actual need)
- [ ] Verify the baseline on AWS, Azure, and GCP — today it is verified on DigitalOcean only; the QEMU rehearsals cover the door topologies (root-user, sudo-user) locally. Per provider: a consumer-shaped harness folder beside the operator's cloud custody (copy the shape of the sandbox's `digital-ocean/`, which began as this repo's `test/integration/digital-ocean/`), with an in-folder `test` steel thread, the provider's bootstrap account as the `LOCK_ACCOUNTS` target, then the standard steel thread + reboot_and_verify. Known risk points to watch: provider images' own cloud-init/sshd drop-ins conflicting with ours (the `sshd -T` asserts will catch it), Azure's provisioning agent vs the first-boot `power_state` reboot, and GCP's guest agent actively managing authorized_keys against the doors model. Expected: near-zero collection changes; mostly per-provider folders. Do not start until a real workload needs one of these providers.

## 8. Environment-repository template (post-release)
- [ ] The day-two-at-scale artifact every runbook implies: inventory of N hosts, pinned collection version, key custody, the scheduled-converge loop, and the standalone verbs wired in — the thing the sandbox's `digital-ocean/` harness is for one host, grown into a real environment shape (likely its own repository, seeded by copying that folder). Seed the site-policy roles from the playbooks parked in the k3s repo's `ansible/` directory (osquery, lynis, postgres — copied there from this repo at 14bc850e). Highest-leverage item for consumers who are not the operator; do not start before the release ships.

## 9. LTS-era migration guide (deferred until the clock forces it)
- [ ] RFC-010 deliberately excludes 24.04 → 26.04 upgrade procedures. The moment 26.04 images are worth targeting, "how do I move a fleet across the era boundary" becomes the top consumer question — new series (`26.4.0`), old series to maintenance, and a documented migration path (likely provision-new-and-adopt-workloads rather than in-place upgrade). No work now; this line exists so the question has a home.

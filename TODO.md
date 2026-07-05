# TODO — cur8s.ubuntu

Open work only, in priority order. `[~]` in progress · `[ ]` not started.
Completed work lives in git history and the RFC Revisions blocks.
Ordering rule for the pre-release pass: every review that can change
code (playbooks, harness, lab) runs before the docs and RFC reads, so
the words are validated against the system as it will actually ship.

## 1. Decide the example catalog deliberately (from the 2026-07-04 product review)
- [ ] Eight examples, each promised on two architectures forever, is a maintenance obligation accumulated rather than chosen. The jobs are: prove composition, and illustrate the archetypes — a packaged service (docker), a downloaded-binary service (zot), an access layer (tailscale), arguably a data service (postgres). Decide: keep all eight knowingly (they double as the operator's seed catalog), or demote the pattern-repeats (k3s, osquery, lynis, and/or postgres) to a cookbook page and shrink the promised surface. Either outcome is fine; the point is that it becomes a decision. Decide before the playbook review so the review covers only what stays.

## 2. Playbook review (code first, on purpose)
- [ ] Read every collection playbook, shared task file, and role with fresh eyes; surface and resolve any concerns (structure, naming, failure modes, output readability). Code changes are unrestricted here — which is exactly why the code reviews precede the docs and RFC reads: what those describe will already be final.
- [ ] Deep-review findings queued for decision (all adversarially verified):
  - C17: locking any account deletes /etc/sudoers.d/90-cloud-init-users wholesale — on a host where that combined file grants several provisioning-time accounts, locking one removes sudo from all. Recommendation: strip only the named account's lines; delete the file only when empty.
  - C11/C18: `cur8s.ubuntu.patch` runs apt's safe upgrade (`upgrade: yes`), but RFC-011 and the docs promise "a full package upgrade." Recommendation: reword the promise to "package upgrade (never removes packages, never reboots)" rather than switching to dist-upgrade on running hosts.
  - T8: rotate_key's input policy checks live only in the localhost play, which `--limit` can skip — a typo'd ROTATE_ACCOUNT would then reach the remote play unvalidated. Recommendation: duplicate the two critical asserts into the remote play.
  - T11 (finder claim rejected by our own lab evidence): a reviewer called the "pubs must be 0600" note wrong; our recorded discovery is that ssh -i with a world-readable pub file does fail. Re-verify once, then keep or fix the folder README's phrasing.

## 3. mise harness review (code)
- [ ] Review the task grammar end to end: task names and descriptions, `lib.sh`, hidden plumbing, the cheat sheet, next-hints, and whether the workflows still read plainly after everything added since the grammar was set. Includes the integration folder's child config (its no-root-`[env]` discipline especially).

## 4. QEMU lab review (code)
- [ ] Review how the lab does images, seeds, boot, wait, and teardown — cross-checked against the explore-qemu learnings — and confirm the scenario flows read as clearly as the baseline flow.

## 5. Docs validation (after the code settles, on purpose)
- [~] The structure is done: the operations manual dissolved into `docs/guides/user-guide.md` (consumer lifecycle + runbooks) and `docs/guides/developer-guide.md` (repo iteration; `AGENTS.md` is the short agent-facing form, `CLAUDE.md` links to it). Remaining: the operator validates the user guide by following it cold against real hosts, audits both guides plus README and role READMEs for gaps, and fixes land as found. While in there: add the one missing lifecycle answer — how a host *leaves* the baseline (stop converging; nothing to uninstall, because the baseline stays near defaults). Docs are validated after the code reviews deliberately: by then every command and behavior the guides describe is final, so a cold read validates the real system instead of a moving one.

## 6. RFC review and approval round
- [ ] Read all twelve RFCs (000–011) end to end and approve each. Check the reading-order arc holds, cross-references are right, statuses are honest, and nothing normative contradicts the code as built — which by this point is settled. Amendments land as part of this item.
- [ ] Deep-review finding C3 (verified): RFC-007 says the first converge closes the pre-baseline door's password authentication, while RFC-005/008 state converge "never removes access" absolutely. Decide the wording refinement — recommendation: the never-removes guarantee is about accounts and their key material; enforcing the global sshd policy IS the baseline's own claim, and RFC-005/008 should say so explicitly.

## 7. First release (RFC-010; after the review pass)
- [ ] Deep-review finding C14: `galaxy.yml` declares `license: []` and no LICENSE file exists anywhere — the first release would ship with no license grant. Choose the license before tagging.
- [ ] Cut `v24.4.0`: bump nothing (version already `24.4.0`), tag, `git push origin main --tags`, then pin the tag in the install snippets. Hygiene first: the docs reference `examples/requirements.yml` files that do not exist (examples resolve via the dev link) — either add per-example requirements files to pin, or fix the references; and pin `test/integration/digital-ocean/requirements.yml` to the tag.

## 8. Multi-provider verification (post-release; gated on actual need)
- [ ] Verify the baseline on AWS, Azure, and GCP — today it is verified on DigitalOcean only; the QEMU scenarios cover the door topologies (root-user, sudo-user) locally. Per provider: a `test/integration/<provider>/` folder (copy-pastable, consumer-shaped, like digital-ocean's) plus a `test:integration:<provider>` orchestrator at root, the provider's bootstrap account as the `LOCK_ACCOUNTS` target, then the standard steel thread + validate_reboot. Known risk points to watch: provider images' own cloud-init/sshd drop-ins conflicting with ours (the `sshd -T` asserts will catch it), Azure's provisioning agent vs the first-boot `power_state` reboot, and GCP's guest agent actively managing authorized_keys against the doors model. Expected: near-zero collection changes; mostly per-provider folders. Do not start until a real workload needs one of these providers.

## 9. Environment-repository template (post-release)
- [ ] The day-two-at-scale artifact every runbook implies: inventory of N hosts, pinned collection version, key custody, the scheduled-converge loop, and the standalone verbs wired in — the thing `test/integration/digital-ocean/` is for one host, grown into a real environment shape (likely its own repository, seeded by copying the folder). Highest-leverage item for consumers who are not the operator; do not start before the release ships.

## 10. LTS-era migration guide (deferred until the clock forces it)
- [ ] RFC-010 deliberately excludes 24.04 → 26.04 upgrade procedures. The moment 26.04 images are worth targeting, "how do I move a fleet across the era boundary" becomes the top consumer question — new series (`26.4.0`), old series to maintenance, and a documented migration path (likely provision-new-and-adopt-workloads rather than in-place upgrade). No work now; this line exists so the question has a home.

# TODO — cur8s.ubuntu

Open work only, in priority order. `[~]` in progress · `[ ]` not started.
Completed work lives in git history and the RFC Revisions blocks.

## 1. Docs validation (pre-release review, first on purpose)
- [~] The structure is done: the operations manual dissolved into `docs/guides/user-guide.md` (consumer lifecycle + runbooks) and `docs/guides/developer-guide.md` (repo iteration; `AGENTS.md` is the short agent-facing form, `CLAUDE.md` links to it). Remaining: the operator validates the user guide by following it cold against real hosts, audits both guides plus README and role READMEs for gaps, and fixes land as found. While in there: add the one missing lifecycle answer — how a host *leaves* the baseline (stop converging; nothing to uninstall, because the baseline stays near defaults). Docs go first deliberately: edge cases discovered here may still change code freely, because the code reviews come later.

## 2. Provider integration restructure (design approved 2026-07-04)
- [~] Built and proven locally; remaining: the first live `test:integration:digital-ocean` run (billable, attended — operator schedules it), which also verifies that the trimmed render still leaves DigitalOcean's root break-glass door (provider machinery) intact. The design, settled decision by decision:
  - `test/integration/digital-ocean/` — a copy-pastable operational skeleton: own child mise file (`vm:*`, `host:*`, `ssh:*`, `key:*`, `up`; pure ops verbs, no test choreography), own helpers, consumer-shaped (`requirements.yml` + dev-mode link to the working tree). Ships 1Password-wired key sourcing as executable documentation; custody stays swappable via the env-driven inputs. `op` becomes a folder-only prerequisite.
  - `test:integration:digital-ocean` at root — DevX orchestrator (via `mise -C`): create → converge ×2 (`changed=0`) → validate-reboot → lock root → assert exactly two doors → destroy on success, keep on failure. Runs ad hoc and at release (RFC-009 gate). Example-suite-on-DO wrappers move under DevX too.
  - QEMU scenario catalog: `qemu:vm:create-root-user-scenario` (new coverage: enter as root, lock root) and `qemu:vm:create-sudo-user-scenario` (username param, default `ubuntu`; absorbs `create-vanilla`), chained sequentially by `qemu:test:scenarios` — one VM at a time, each story reported on its own. Vocabulary: "specimen" → "scenario" everywhere.
  - The neutral render drops `- default` and `disable_root: false` — provider doors are provider facts (RFC-006); verify live: trimmed render on DO still leaves root break-glass (provider machinery), QEMU baseline VM born with exactly two accounts.
  - Spike-proven mechanics: child tasks invisible at root; `mise -C` orchestration works; `MISE_CONFIG_ROOT` points at the folder (copy-paste survives); folder tasks must not lean on root `[env]`; one-time `mise trust` per folder.
  - Docs sweep with the change: both guides, README, cheat sheet, RFC-011 examples note if needed.

## 3. Close the forever-loop gap (from the 2026-07-04 product review)
- [ ] The product promises "kept conformant forever" but ships nothing that creates the *next converge*. Two adds, aligned before coding: (a) a **drift-check verb** — converge's `--check` mode productized as a task in the qemu family and the integration folder (likely a wrapper flag, no new playbook; if it stays wrapper-only, RFC-011 is untouched), so "is anything drifting?" is one command whose output is the alarm; (b) a **scheduled-converge story** — a user-guide section (or minimal example) showing the loop a consumer actually runs: converge on a schedule from an environment repo's CI or a systemd timer, `changed≠0` as the alert condition (RFC-004 already assumes this loop exists; the product should show one). Lands before the review pass so reviews see the final surface.

## 4. Decide the example catalog deliberately (from the 2026-07-04 product review)
- [ ] Eight examples, each promised on two architectures forever, is a maintenance obligation accumulated rather than chosen. The jobs are: prove composition, and illustrate the archetypes — a packaged service (docker), a downloaded-binary service (zot), an access layer (tailscale), arguably a data service (postgres). Decide: keep all eight knowingly (they double as the operator's seed catalog), or demote the pattern-repeats (k3s, osquery, lynis, and/or postgres) to a cookbook page and shrink the promised surface. Either outcome is fine; the point is that it becomes a decision. Decide before the playbook review so the review covers only what stays.

## 5. RFC review and approval round
- [ ] Read all twelve RFCs (000–011) end to end and approve each. Check the reading-order arc holds, cross-references are right, statuses are honest, and nothing normative contradicts the code as built. Amendments land as part of this item.
- [ ] Deep-review finding C3 (verified): RFC-007 says the first converge closes the pre-baseline door's password authentication, while RFC-005/008 state converge "never removes access" absolutely. Decide the wording refinement — recommendation: the never-removes guarantee is about accounts and their key material; enforcing the global sshd policy IS the baseline's own claim, and RFC-005/008 should say so explicitly.

## 6. Playbook review
- [ ] Read every collection playbook, shared task file, and role with fresh eyes; surface and resolve any concerns (structure, naming, failure modes, output readability). Code changes are unrestricted here — that freedom is why this comes after docs.
- [ ] Deep-review findings queued for decision (all adversarially verified):
  - C17: locking any account deletes /etc/sudoers.d/90-cloud-init-users wholesale — on a host where that combined file grants several provisioning-time accounts, locking one removes sudo from all. Recommendation: strip only the named account's lines; delete the file only when empty.
  - C11/C18: `cur8s.ubuntu.patch` runs apt's safe upgrade (`upgrade: yes`), but RFC-011 and the docs promise "a full package upgrade." Recommendation: reword the promise to "package upgrade (never removes packages, never reboots)" rather than switching to dist-upgrade on running hosts.
  - T8: rotate_key's input policy checks live only in the localhost play, which `--limit` can skip — a typo'd ROTATE_ACCOUNT would then reach the remote play unvalidated. Recommendation: duplicate the two critical asserts into the remote play.
  - T11 (finder claim rejected by our own lab evidence): a reviewer called the "pubs must be 0600" note wrong; our recorded discovery is that ssh -i with a world-readable pub file does fail. Re-verify once, then keep or fix the folder README's phrasing.

## 7. mise harness review
- [ ] Review the task grammar end to end: task names and descriptions, `lib.sh`, hidden plumbing, the cheat sheet, next-hints, and whether the workflows still read plainly after everything added since the grammar was set. Includes the integration folder's child config (its no-root-`[env]` discipline especially).

## 8. QEMU lab review
- [ ] Review how the lab does images, seeds, boot, wait, and teardown — cross-checked against the explore-qemu learnings — and confirm the scenario flows read as clearly as the baseline flow.

## 9. First release (RFC-010; after the review pass)
- [ ] Deep-review finding C14: `galaxy.yml` declares `license: []` and no LICENSE file exists anywhere — the first release would ship with no license grant. Choose the license before tagging.
- [ ] Cut `v24.4.0`: bump nothing (version already `24.4.0`), tag, `git push origin main --tags`, then pin the tag in the install snippets. Hygiene first: the docs reference `examples/requirements.yml` files that do not exist (examples resolve via the dev link) — either add per-example requirements files to pin, or fix the references; and pin `test/integration/digital-ocean/requirements.yml` to the tag.

## 10. Multi-provider verification (post-release; gated on actual need)
- [ ] Verify the baseline on AWS, Azure, and GCP — today it is verified on DigitalOcean only; the QEMU scenarios cover the door topologies (root-user, sudo-user) locally. Per provider: a `test/integration/<provider>/` folder (copy-pastable, consumer-shaped, like digital-ocean's) plus a `test:integration:<provider>` orchestrator at root, the provider's bootstrap account as the `LOCK_ACCOUNTS` target, then the standard steel thread + validate_reboot. Known risk points to watch: provider images' own cloud-init/sshd drop-ins conflicting with ours (the `sshd -T` asserts will catch it), Azure's provisioning agent vs the first-boot `power_state` reboot, and GCP's guest agent actively managing authorized_keys against the doors model. Expected: near-zero collection changes; mostly per-provider folders. Do not start until a real workload needs one of these providers.

## 11. Environment-repository template (post-release)
- [ ] The day-two-at-scale artifact every runbook implies: inventory of N hosts, pinned collection version, key custody, the scheduled-converge loop, and the standalone verbs wired in — the thing `test/integration/digital-ocean/` is for one host, grown into a real environment shape (likely its own repository, seeded by copying the folder). Highest-leverage item for consumers who are not the operator; do not start before the release ships.

## 12. LTS-era migration guide (deferred until the clock forces it)
- [ ] RFC-010 deliberately excludes 24.04 → 26.04 upgrade procedures. The moment 26.04 images are worth targeting, "how do I move a fleet across the era boundary" becomes the top consumer question — new series (`26.4.0`), old series to maintenance, and a documented migration path (likely provision-new-and-adopt-workloads rather than in-place upgrade). No work now; this line exists so the question has a home.

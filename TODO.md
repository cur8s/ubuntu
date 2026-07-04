# TODO — cur8s.ubuntu

Open work only, in priority order. `[~]` in progress · `[ ]` not started.
Completed work lives in git history and the RFC Revisions blocks.

## 1. Docs validation (pre-release review, first on purpose)
- [~] The structure is done: the operations manual dissolved into `docs/guides/user-guide.md` (consumer lifecycle + runbooks) and `docs/guides/developer-guide.md` (repo iteration; `AGENTS.md` is the short agent-facing form, `CLAUDE.md` links to it). Remaining: the operator validates the user guide by following it cold against real hosts, audits both guides plus README and role READMEs for gaps, and fixes land as found. Docs go first deliberately: edge cases discovered here may still change code freely, because the code reviews come later.

## 2. Provider integration restructure (design approved 2026-07-04)
- [~] Providers become self-contained integration folders. The design, settled decision by decision:
  - `test/integration/digital-ocean/` — a copy-pastable operational skeleton: own child mise file (`vm:*`, `play:*`, `ssh:*`, `key:*`, `up`; pure ops verbs, no test choreography), own helpers, consumer-shaped (`requirements.yml` + dev-mode link to the working tree). Ships 1Password-wired key sourcing as executable documentation; custody stays swappable via the env-driven inputs. `op` becomes a folder-only prerequisite.
  - `e2e:digital-ocean` at root — DevX orchestrator (via `mise -C`): create → converge ×2 (`changed=0`) → validate-reboot → lock root → assert exactly two doors → destroy on success, keep on failure. Runs ad hoc and at release (RFC-009 gate). Example-suite-on-DO wrappers move under DevX too.
  - QEMU scenario catalog: `qemu:vm:create-root-user-scenario` (new coverage: enter as root, lock root) and `qemu:vm:create-sudo-user-scenario` (username param, default `ubuntu`; absorbs `create-vanilla`), chained sequentially by `qemu:test:scenarios` — one VM at a time, each story reported on its own. Vocabulary: "specimen" → "scenario" everywhere.
  - The neutral render drops `- default` and `disable_root: false` — provider doors are provider facts (RFC-006); verify live: trimmed render on DO still leaves root break-glass (provider machinery), QEMU baseline VM born with exactly two accounts.
  - Spike-proven mechanics: child tasks invisible at root; `mise -C` orchestration works; `MISE_CONFIG_ROOT` points at the folder (copy-paste survives); folder tasks must not lean on root `[env]`; one-time `mise trust` per folder.
  - Docs sweep with the change: both guides, README, cheat sheet, RFC-011 examples note if needed.

## 3. RFC review and approval round
- [ ] Read all twelve RFCs (000–011) end to end and approve each. Check the reading-order arc holds, cross-references are right, statuses are honest, and nothing normative contradicts the code as built. Amendments land as part of this item.

## 4. Playbook review
- [ ] Read every collection playbook, shared task file, and role with fresh eyes; surface and resolve any concerns (structure, naming, failure modes, output readability). Code changes are unrestricted here — that freedom is why this comes after docs.

## 5. mise harness review
- [ ] Review the task grammar end to end: task names and descriptions, `lib.sh`, hidden plumbing, the cheat sheet, next-hints, and whether the workflows still read plainly after everything added since the grammar was set.

## 6. QEMU lab review
- [ ] Review how the lab does images, seeds, boot, wait, and teardown — cross-checked against the explore-qemu learnings — and confirm the scenario flows read as clearly as the baseline flow.

## 7. First release (RFC-010; after the review pass)
- [ ] Cut `v24.4.0`: bump nothing (version already `24.4.0`), tag, `git push origin main --tags`, then pin the tag in `examples/requirements.yml` and the user guide's install snippets.

## 8. Multi-provider verification (post-release; gated on actual need)
- [ ] Verify the baseline on AWS, Azure, and GCP — today it is verified on DigitalOcean only; the QEMU scenarios cover the door topologies (root-user, sudo-user) locally. Per provider: a `test/integration/<provider>/` folder (copy-pastable, consumer-shaped, like digital-ocean's) plus an `e2e:<provider>` orchestrator at root, the provider's bootstrap account as the `LOCK_ACCOUNTS` target, then the standard steel thread + validate_reboot. Known risk points to watch: provider images' own cloud-init/sshd drop-ins conflicting with ours (the `sshd -T` asserts will catch it), Azure's provisioning agent vs the first-boot `power_state` reboot, and GCP's guest agent actively managing authorized_keys against the doors model. Expected: near-zero collection changes; mostly per-provider folders. Do not start until a real workload needs one of these providers.

# Note: Multi-host proof — design

Status: Approved design (2026-07-07), to be implemented as `test:fleet`.
The TODO's "Multi-host proof" item points here; this note retires into
git history when the suite lands.

## The gap

The product claim is a fleet: an environment repository converging N
hosts from one inventory, on a schedule, forever (RFC-001: The Host
Baseline; RFC-008: Convergence). Every proof this repository has ever
run — every suite, every CI pass, the provider gate — is N=1: one VM,
an inventory of exactly one host.

The playbooks are fleet-shaped by construction — `converge`,
`report_access`, and `rotate_key` all run their host play against
`hosts: all` — but construction is not proof, and N=1 is exactly the
world where a whole class of multi-host bugs passes vacuously.

## What N=2 catches that N=1 cannot

- **Cross-host contamination in delegated work.** The access probes
  delegate to localhost carrying per-host connection facts (address,
  port, account). A hostvars mixup would prove host A's door using
  host B's port — a pass at N=1 no matter how wrong the plumbing is.
- **Play-scoped state bleed.** Anything `run_once`, any registered
  variable or fact computed on one host and consumed on another.
- **Rotation at fleet scale.** The baseline keys are fleet-wide
  identities (RFC-004: Identity and Trust): one invocation must re-key
  every host in inventory to the same new key, entering each through
  its sibling door, and a failure partway through the fleet must leave
  every host recoverable (old or new key working via the sibling).
  Never demonstrated beyond one host.
- **Idempotency at N.** `changed=0` on the second converge means every
  host's recap line, simultaneously.
- **Report readability at N.** `report_access` exists for human
  judgment; two hosts' output interleaved could be unreadable, and
  confusing output is a defect here, not a cosmetic issue.

N=2 is the smallest world where every bug in this class is visible;
nothing in the class needs N=3.

## The proof: `test:fleet`

One suite, the standard sentence told to two hosts at once:

1. Build and start two fresh provisioned VMs in their own slots
   (below); the standing lab slot is not required and not touched.
2. Write one inventory holding both; converge the fleet.
3. Converge again: `changed=0` (`assert_changed_zero` is already
   N-safe — any host reporting changes trips it), plus an explicit
   assert that **both** hosts appear in the recap, so a silently
   dropped host cannot read as a clean pass.
4. `report_access` across the fleet: each host's report present and
   complete (two doors each), and the output judged readable.
5. Attribution assert, from the logs: each host's delegated probe
   connected to *its own* port (pair hostname to port in the probe's
   command line) — the cross-contamination class, checked directly.
6. Rotation round trip: rotate `ansible` across the fleet with the
   same key-file-swap choreography as `test:rotation`; assert both
   hosts refuse the old key and open to the new one; rotate back.
7. Final converge `changed=0`; destroy both slots.

## The slot seam (the design decision)

The vendored harness is already slot-parameterized: a VM *is* a
directory, and `QVM_DIR`, `QVM_NAME`, `QVM_SSH_PORT` are environment
with defaults. The single-slot-ness lives entirely in `mise.toml`,
whose `[env]` pins win over a caller's exports (verified:
`QVM_NAME=zzz mise x -- printenv QVM_NAME` prints `ubuntu-qemu-lab`).

The seam: those three pins become defaults that yield —
`{{ get_env(name='QVM_NAME', default='ubuntu-qemu-lab') }}` and
siblings — which is what the surrounding comment already promises
("override per-run via environment") and the pins currently break.

The accepted risk: a stray ambient `QVM_*` could retarget a task
per-invocation. These variables carry no secrets — unlike the
`*_PUB_KEY` pins, whose exports-always-win behavior is the deliberate
anti-vault-leak guard and does not change — and `vm:status` already
reads occupant truth from the seed rather than from env, so a lying
environment is visible, not silent.

Slots for this suite: names `ubuntu-qemu-fleet-1` / `-2`, state dirs
`.generated/qemu/fleet-1` / `-2`, ports `2231` / `2232` — well clear
of the standing lab's `2222`, so a fleet run can never collide with
whatever the standing slot holds. The image cache stays shared
(`QVM_CACHE_DIR` unchanged): both slots boot the same verified image
without a second download.

## Fleet connection mechanics (suite-local, deliberately)

- Inventory: two lines of
  `<name> ansible_host=127.0.0.1 ansible_port=<port>`, written by the
  suite. The named alias remains load-bearing (a host literally named
  `127.0.0.1` would swallow `delegate_to: localhost`).
- known_hosts: concatenate both VMs' files into the suite's own —
  entries are keyed `[127.0.0.1]:<port>`, so the two cannot collide.
- Credentials: the same shim, the same lab agent, the same
  `IdentityAgent` pin as `run_lab_playbook` — one identity for the
  whole fleet is not a shortcut, it is the product claim (RFC-004).
- The helper stays inside the suite. The collection-shipped
  `run-lab-playbook.sh` keeps its one-VM contract; a second consumer
  needing fleet runs is what would promote the helper to the
  collection, the same rule that governed the qemu-vm.sh extraction.

## What stays shelved

The fuller fleet harness from the parallelization discussion — slot
pools, suites running concurrently against separate VMs, a slot
catalog — stays shelved. This seam decides none of it and blocks none
of it. Builds and boots run sequentially in the first version;
overlapping boots are a wall-clock optimization to take later, not
part of the proof.

## CI

`test:fleet` joins the main ladder, not the PR lane. Cost is roughly
two `up` legs plus three fleet plays — the ladder's slowest suites are
in that neighborhood already. Two VMs at default sizes fit the
standard runner; the suite requires no standing lab and destroys its
own slots, so it leaves CI exactly as it found it.

## Touched surfaces

- `mise.toml`: the three `QVM_*` pins become `get_env` defaults.
- `mise-tasks/test/fleet`: the new suite.
- `.github/workflows/ci.yml`: the ladder entry.
- Docs: the developer guide's suite descriptions follow.
- The collection: no changes expected — the entire point is that the
  playbooks already claim to be fleet-safe. Anything the proof forces
  is a finding, landed as its own ruled change.

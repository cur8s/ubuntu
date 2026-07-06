# RFC-007: Adoption

Status: Accepted

Provisioning produces hosts born conformant (RFC-006: Provisioning). Adoption is for every host that already exists — bare metal installed by whatever means, servers already running workloads — and its contract is provisioning's contract reached from the other side: a supported Ubuntu installation, reachable over SSH by the baseline identities. The moment `ansible` and `sysadmin` work, adoption is over; converge, the gates, and door-closing take the host from there, unchanged.

What makes adoption a distinct problem is history. A provisioned host starts empty; an adopted host starts unknown. Everything below follows from refusing to guess about the unknown.

## Assess, Then Add

Adoption is two artifacts with a fixed division of labor.

**The assessment** connects as the pre-existing user, writes nothing, and renders a verdict: hard failures that block adoption until a human acts (an unsupported release, no path to root, sshd or sudoers configured to ignore drop-in directories — the baseline's files would be silently inert — and squatted baseline accounts), warnings naming exactly what the first converge will change on this host (password authentication disabled, competing sshd drop-ins, the expected first-converge delta), and the host's access surface (RFC-005: Accounts and Access) — every door and privilege holder the operator is about to take responsibility for.

**Adopt** re-runs the same checks, refuses on any hard failure, and then only adds: the two baseline accounts, their keys, their sudoers files, followed by proof that both can SSH in and use sudo. It edits nothing that exists, removes nothing, restarts nothing. There are no policy knobs and no force flag on either artifact: ambiguity refuses, additions coexist, and overwriting happens only later, only by converge, and only on surface the baseline owns.

## Squatting

An `ansible` or `sysadmin` account that already exists with any key the baseline did not put there — even alongside correct baseline keys — is a hard failure. The tool never merges into, and never strips, an account whose ownership it cannot prove; the refusal names the unexpected keys and a human resolves them. A stale key from an earlier rotation reads as unexpected on purpose — an old key is still a door someone may hold; remove it, then re-assess. An account matching baseline shape exactly reports as already adopted: adopting twice, or adopting a baseline-born host, changes nothing.

## The Pre-Baseline Door

The account adoption connects through — the installer-created user, whatever the host's history left — is RFC-004's bootstrap identity generalized: the door that makes the host reachable until the baseline doors are proven, closed afterward. Its authentication is whatever the host has. This is the one moment password authentication is tolerated, because it is what exists; the first converge afterward closes it.

Afterward the old doors are closed deliberately — locked by name (RFC-005: Accounts and Access), or deleted by a human — never automatically. The assessment's access surface is the worklist.

## The Runbook

Each stage is gated by the one before it, and the old access path survives until the new one is proven:

```
assess → adopt → converge → reboot_and_verify → lock old doors
```

The first three make the host conformant; the gate (RFC-009: Validation and Acceptance) proves it survives a boot cycle; closing the pre-baseline doors is the operator's deliberate final act, in that order because there must never be a moment without a proven access path.

## Scope

This RFC defines adoption's contract, the assess-then-add division, the verdict semantics, the squatting refusal, and the pre-baseline door lifecycle.

It does not define the account taxonomy or the lock mechanism (RFC-005: Accounts and Access), provisioning at birth (RFC-006: Provisioning), convergence semantics (RFC-008: Convergence), the acceptance gates (RFC-009: Validation and Acceptance), or the artifact names consumers rely on (RFC-011: Conventions Contract).

## Revisions

Initial version.

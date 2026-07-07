# RFC-002: Baseline Doctrine

Status: Accepted

RFC-001: The Host Baseline establishes the two-tier model: an immovable baseline of invariants beneath optional layers. This RFC defines what qualifies a control for the baseline, and the doctrine baseline roles are written under.

## The Baseline Inclusion Test

A control belongs in the baseline only if all three hold:

1. It is a security or correctness invariant for any production Ubuntu host, regardless of the host's role.
2. There is no legitimate reason it would ever need to be off.
3. Enforcing it cannot break arbitrary future workloads or lock the operator out.

Expanding the baseline requires architectural justification recorded in RFC-003: Baseline Contents. Convenience for a particular workload is never sufficient.

## Pins, Not Checks

The baseline stays as close to distro defaults as possible. A baseline role declares only what must be pinned: a setting that diverges from the default, or a default that must hold unconditionally where the distro leaves it conditional. Anything the default already guarantees is trusted, not enforced.

Declared configuration is a maintenance liability: every pin must track upstream changes for as long as it exists. Nothing declared means nothing to maintain — and a default can always be pinned later, when evidence demands it.

Baseline roles contain no verification-only code: no probes or assertions that check state without declaring it. Verification of outcomes belongs to acceptance gates (RFC-009: Validation and Acceptance), where it runs deliberately rather than on every converge.

Preflight guards are not checks in this sense. Converge may assert its preconditions — required inputs, and that the host runs the Ubuntu release this baseline series targets (RFC-010: Release and Versioning) — before mutating anything. A guard protects the host from the wrong baseline; a check second-guesses the right one.

Exclusion is reversible and cheap; premature inclusion is not. When in doubt, a control stays out of the baseline until a real incident supplies the evidence.

## Ownership: Floors, Not Practices

The baseline is a floor, not a practice. A practice — a scanner's configuration, fleet hygiene, site policy — churns as opinion and circumstance change. A floor freezes: it releases when the facts beneath it change (a new Ubuntu release, an upstream default shift), never because a layer above it changed its mind.

The test for what the baseline may own is version pressure: if changing your mind about X would force a release of Y, X does not belong in Y. Whatever fails that test against the baseline lives above it — in its own versioned collection when it carries a real contract of its own, or in the consumer's environment repository when it is site policy.

And composition reaches only upward: layers import and enforce the baseline (RFC-001: The Host Baseline); the baseline never tests, promises, or names a particular layer above it.

## Scope

This RFC defines what qualifies a control for the baseline, the doctrine baseline roles are written under, and the ownership doctrine — floors versus practices — that decides where work lives.

It does not enumerate the baseline's contents (RFC-003: Baseline Contents) or define the acceptance gates that verify outcomes (RFC-009: Validation and Acceptance).

## Revisions

Initial version.

Renamed from Floor Doctrine; "baseline" now names the invariant tier throughout the series.

Clarified that preflight guards (converge preconditions, including the release guard) are permitted and are not verification-only code.

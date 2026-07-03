# RFC-002: Floor Doctrine

Status: Accepted

The baseline is a two-tier model.

The immovable floor is a fixed set of invariants: always enforced, never turned off, re-asserted on every converge on every host. Layers are everything optional or overridable. Being disable-able is what makes something a layer. Layers add posture; the floor is minimal.

## The Floor Inclusion Test

A control belongs in the floor only if all three hold:

1. It is a security or correctness invariant for any production Ubuntu host, regardless of the host's role.
2. There is no legitimate reason it would ever need to be off.
3. Enforcing it cannot break arbitrary future workloads or lock the operator out.

Expanding the floor requires architectural justification recorded in RFC-003: Floor Contents. Convenience for a particular workload is never sufficient.

## Pins, Not Checks

The floor stays as close to distro defaults as possible. A floor role declares only what must be pinned: a setting that diverges from the default, or a default that must hold unconditionally where the distro leaves it conditional. Anything the default already guarantees is trusted, not asserted.

Declared configuration is a maintenance liability: every pin must track upstream changes for as long as it exists. Nothing declared means nothing to maintain — and a default can always be pinned later, when evidence demands it.

Floor roles contain no verification-only code: no probes or assertions that check state without declaring it. Verification of outcomes belongs to acceptance gates (RFC-007: Validation and Acceptance), where it runs deliberately rather than on every converge.

Exclusion is reversible and cheap; premature inclusion is not. When in doubt, a control stays out of the floor until a real incident supplies the evidence.

## Scope

This RFC defines what qualifies a control for the floor and the doctrine floor roles are written under.

It does not enumerate the floor's contents (RFC-003: Floor Contents) or define the acceptance gates that verify outcomes (RFC-007: Validation and Acceptance).

## Revisions

Initial version.

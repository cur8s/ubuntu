# RFC-000: The Role of RFCs

Status: Accepted

This repository defines an opinionated baseline for Ubuntu Server systems.

The purpose of these RFCs is to capture the architectural reasoning that constrains how the repository evolves. They define the models, boundaries, and constraints that preserve the identity of the system over time.

RFCs are normative. They prescribe what must remain true rather than documenting how the repository happens to be implemented today. Roles, playbooks, cloud-init assets, directory layouts, and tooling may evolve freely provided they continue to satisfy the architectural constraints established by the RFCs.

Any change that violates an accepted RFC is an architectural change and must be introduced through a new RFC that explicitly supersedes or amends the existing one.

RFCs are authoritative but not immutable. Improvements that clarify intent, make implicit reasoning explicit, or improve readability may be incorporated directly into an RFC and recorded as revisions. Changes that alter architectural meaning, scope, or constraints require a new RFC or an explicit revision recorded against the affected RFC.

RFCs deliberately describe what the system is and why it exists, not how it is operated or implemented. The guides (`docs/guides/`) own the how and the map: an architecture guide that narrates the whole system end to end and points into the RFCs for the normative detail, a user guide for consuming the baseline, and a developer guide for iterating on this repository. The architecture guide is the recommended starting point for building a mental model — it is navigational by design, never a second source of truth; where it and an RFC differ, the RFC wins like everything else here. It makes explicit the guided reading that this series' numbering only implies. Engineering notes (`docs/notes/`) preserve the thinking around the architecture: evidence from incidents and experiments, and recorded designs that are not commitments. Runnable examples (`examples/`) illustrate consumption and prescribe nothing. Real-provider verification is load-bearing for release (RFC-009: Validation and Acceptance) but lives outside the repository: consumer-shaped harness folders kept beside the operator's cloud custody, each self-contained and liftable, doubling as a worked operational skeleton.

The audience for these RFCs is anyone evolving or consuming this repository: contributors, users deciding whether to adopt the baseline, and AI coding agents working in the tree. They provide a stable architectural contract that allows implementation details to change without changing the identity of the system.

RFC numbers are stable identifiers. They are never renumbered or reused. In this series the numbers happen to follow the recommended reading order, but the identifiers, not the order, are what stay stable. An earlier RFC series from the playbook prototype that preceded this repository used its own numbering; that series is retired and its numbers carry no meaning here.

Each RFC declares a status. `Accepted` RFCs are in force. `Draft` RFCs record direction not yet proven by implementation. `Example` documents illustrate possibilities without prescribing anything.

## Scope

This RFC defines the purpose, authority, and evolution model of the baseline RFCs.

It does not define the baseline itself, the supported operating system releases, the security posture, or the automation architecture. Those concerns are established by subsequent RFCs.

## Revisions

Initial version.

Simplified the documentation taxonomy: design sketches live in `docs/notes/` alongside evidence; `docs/examples/` is retired in favor of the runnable `examples/`.

Added the architecture guide to the taxonomy: the narrative map that builds the end-to-end mental model and points into the RFCs, non-normative by design.

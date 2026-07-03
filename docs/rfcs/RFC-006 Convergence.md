# RFC-006: Convergence

Status: Accepted

A provisioned host is only reachable; converge is what makes and keeps it conformant.

Desired state is declared in git; converge re-asserts it. Drift — an out-of-band change by a person or an AI agent — is reverted on the next converge. Only declared, in-git changes stick. This makes every change attributable: the git commit is the who and why, the converge run is the what and when.

Convergence is agentless: Ansible pushes over standard SSH through the `ansible` account. No per-host agent, no self-healing daemon. Reconciliation is on demand — ad-hoc from an operator workstation or on a schedule from an environment repository — and it is the same playbook either way.

## Steady State Is a No-Op

Converge is idempotent. On a conformant host every run reports zero changes, and the first converge after provisioning is already a no-op for everything first boot applied (RFC-005: Provisioning). A non-zero change count on a steady-state host is a drift report, not noise.

Detection and enforcement are one playbook and one flag: check mode reports what differs without changing anything; a normal run enforces. Roles are authored check-mode-clean — read-only probes never report change and still run under check mode — so the drift report is trustworthy.

## Composition

A purpose layer's converge imports the baseline converge first, then applies its own purpose. Every tier re-asserts the floor (RFC-001: The Host Baseline).

## Ansible Is an Implementation Choice

Ansible was selected because it operates over standard SSH, requires no host-side agent, and is idempotent by design. A future convergence mechanism is acceptable provided it preserves the architectural properties: an external git source of truth, repeatable convergence, drift correction, trustworthy detection without enforcement, and no required host-side agent.

## Scope

This RFC defines convergence semantics: the source of truth, the drift model, idempotency, and detection.

It does not define what converge asserts (RFC-003: Floor Contents), provisioning (RFC-005: Provisioning), or acceptance testing (RFC-007: Validation and Acceptance).

## Revisions

Initial version.

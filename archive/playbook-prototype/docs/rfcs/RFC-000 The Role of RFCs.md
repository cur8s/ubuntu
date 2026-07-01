RFC-000: The Role of RFCs

Status: Accepted

This repository defines an opinionated architecture for Ubuntu Server systems.

The purpose of these RFCs is to capture the architectural reasoning that constrains how the repository evolves. They define the models, boundaries, and constraints that preserve the identity of the system over time.

RFCs are normative. They prescribe what must remain true rather than documenting how the repository happens to be implemented today. Scripts, Ansible playbooks, cloud-init files, autoinstall configuration, directory layouts, and tooling may evolve freely provided they continue to satisfy the architectural constraints established by the RFCs.

Any change that violates an accepted RFC is an architectural change and must be introduced through a new RFC that explicitly supersedes or amends the existing one.

RFCs are authoritative but not immutable. Improvements that clarify intent, make implicit reasoning explicit, or improve readability may be incorporated directly into an RFC and recorded as revisions. Changes that alter architectural meaning, scope, or constraints require a new RFC.

RFCs deliberately describe what the system is and why it exists, not how it is implemented. Operational guides, installation instructions, repository layout, implementation notes, and automation belong elsewhere in the documentation.

The audience for these RFCs is anyone evolving this repository: humans, automation, and AI coding agents. They provide a stable architectural contract that allows implementation details to change without changing the identity of the system.

RFC numbers are stable identifiers, not a reading order. They are never renumbered or reused. The recommended reading order is maintained separately from the identifiers themselves.

**Scope**

This RFC defines the purpose, authority, and evolution model of the Ubuntu RFCs.

It does not define the Ubuntu host model, supported operating system versions, security posture, package policy, or automation architecture. Those concerns are established by subsequent RFCs.

**Revisions**

Initial version.

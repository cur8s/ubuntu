RFC-005: Baseline Convergence

Status: Accepted

A provisioned host is only reachable; it is not yet conformant.

Baseline convergence transforms a supported Ubuntu installation into a host that conforms to the Host Baseline and maintains that conformance over time. It installs packages, configures the operating system, hardens security, manages services, verifies conformance, and corrects configuration drift.

The authoritative definition of the Host Baseline lives in the Host Control Repository, a version-controlled Git repository. It contains the provisioning assets, baseline configuration, convergence automation, verification, and documentation required to reproduce the Host Baseline.

Because the repository is the source of truth, every change is reviewable and reproducible. Manual changes made directly on a host are transient. If a configuration decision matters, it belongs in the Host Control Repository and is applied through baseline convergence.

Ansible

The Host Control Repository uses Ansible as its convergence engine.

Ansible was selected because it operates over standard SSH, requires no agent on managed hosts, is idempotent by design, and applies the same automation to newly provisioned and long-lived hosts.

This keeps the architecture simple: Git is the source of truth, the Host Control Repository is the control plane, Ansible performs convergence, and managed hosts remain ordinary Ubuntu systems.

Ansible is an implementation choice rather than an architectural requirement. Future convergence mechanisms are acceptable provided they preserve the same architectural properties: an external source of truth, repeatable convergence, configuration drift correction, and no required host-side management agent.

Scope

This RFC defines how hosts become and remain conformant after provisioning.

It does not define provisioning, the organization of the Host Control Repository, or the implementation details of Ansible playbooks.

Revisions

Initial version.
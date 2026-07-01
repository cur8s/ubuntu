# Baseline Playbooks

Top-level playbooks are the intended entry points:

* `initialize.yml` establishes non-root SSH access for a newly reachable host.
* `converge.yml` applies the steady-state Host Baseline.

Supporting playbooks are grouped by responsibility:

* `access/` manages administrative users, SSH keys, OpenSSH policy, and access validation.
* `packages/` manages Ubuntu package maintenance and explicit reboot handling.
* `preflight/` checks host prerequisites before convergence.

Composed access playbooks:

* `access/initialize.yml` creates and validates the baseline `ansible` and `admin` users.
* `access/converge.yml` applies the steady-state SSH trust and OpenSSH policy.
* `access/ensure-access-user.yml` is the reusable single-user setup playbook used by initialization.

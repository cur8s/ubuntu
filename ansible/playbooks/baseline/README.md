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
* `access/add-ssh-sudo-user.yml` is the reusable single-user setup playbook used by initialization.
* `access/tasks/add-passwordless-sudo-user.yml` is the reusable user and sudo task file used by `access/add-ssh-sudo-user.yml`.
* `access/tasks/install-ed25519-authorized-key.yml` installs a provided Ed25519 SSH public key for a user.
* `access/validate-ssh-sudo-access.yml` proves initialized users can connect over SSH and run passwordless sudo.
* `access/trust-bootstrap-ssh-key.yml` preserves the bootstrap and recovery SSH key.
* `access/configure-openssh-policy.yml` applies the baseline OpenSSH server policy.

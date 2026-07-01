# Baseline Playbooks

Top-level playbooks are the intended entry points:

* `initialize.yml` establishes non-root SSH access for a newly reachable host.
* `converge.yml` applies the steady-state Host Baseline.

Supporting playbooks are grouped by responsibility:

* `users/` manages administrative users, sudo access, per-user SSH keys, and user access validation.
* `ssh/` manages the system OpenSSH server policy.
* `packages/` manages Ubuntu package maintenance and explicit reboot handling.
* `preflight/` checks host prerequisites before convergence.

User playbooks:

* `users/initialize.yml` creates and validates the baseline `ansible` and `admin` users.
* `users/tasks/add-passwordless-sudo-user.yml` is the reusable user and sudo task file used by `users/initialize.yml`.
* `users/tasks/install-ssh-authorized-key.yml` installs a provided SSH public key for a user.
* `users/validate-ssh-sudo-access.yml` proves initialized users can connect over SSH and run passwordless sudo.

SSH playbooks:

* `ssh/converge.yml` applies the steady-state SSH trust and OpenSSH policy.
* `ssh/trust-bootstrap-ssh-key.yml` preserves the bootstrap and recovery SSH key.
* `ssh/configure-openssh-policy.yml` applies the baseline OpenSSH server policy.

# Ubuntu Ansible Collection

This repository is being rebuilt as the `baseline.ubuntu` Ansible collection.

The current steel thread is:

1. Extract SSH public keys from 1Password.
2. Create a temporary DigitalOcean Ubuntu VM with the provider bootstrap key.
3. Initialize replacement access with Ansible over the provider bootstrap SSH path.
4. Validate that the fixed `ansible` and `admin` users can SSH and use passwordless sudo.
5. Switch Ansible to the new `ansible` SSH path and lock down OpenSSH.
6. Validate `ansible` and `admin` access again after lockdown.

```sh
mise run key:extract
mise run key:upload
mise run vm:create
mise run vm:init
```

After `vm:init`, normal reruns should use the `ansible` account:

```sh
mise run vm:converge
```

The current SSH policy keeps root public key login available as a bootstrap
recovery path while disabling password-based SSH. Removing bootstrap root access
is a later milestone after the replacement access path passes reboot validation.

Reboot validation:

```sh
mise run vm:reboot
mise run ssh:ansible
mise run ssh:admin
```

SSH shortcuts:

```sh
mise run ssh:root
mise run ssh:ansible
mise run ssh:admin
```

## Ansible Shape

`roles/users` contains the idempotent user state. It creates users, installs authorized keys, grants passwordless sudo, and verifies sudo with Ansible modules where modules fit the job.

`roles/ssh` contains the idempotent OpenSSH daemon policy. It writes a fixed
`sshd_config.d` drop-in, validates it with `sshd -t`, reloads `ssh`, and asserts
the effective policy with `sshd -T`.

`playbooks/initialize.yml` is the first-time VM initialization path. It starts
over root bootstrap SSH only long enough to create and validate replacement
users, then switches to the `ansible` account before applying SSH lockdown.

`playbooks/converge.yml` is the normal rerun path after initialization. It
connects as `ansible`, applies the baseline roles, and validates access.

`mise.toml` is contributor convenience only. It can call 1Password, DigitalOcean, and Ansible for local development, but provider and secret-manager behavior should not move into reusable collection roles.

The previous playbook-oriented prototype has been moved to:

```text
archive/playbook-prototype/
```

That archive remains useful reference material while the collection shape is rebuilt one piece at a time.

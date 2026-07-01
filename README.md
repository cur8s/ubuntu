# Ubuntu Ansible Collection

This repository is being rebuilt as the `baseline.ubuntu` Ansible collection.

The current steel thread is:

1. Extract SSH public keys from 1Password.
2. Create a temporary DigitalOcean Ubuntu VM with the provider bootstrap key.
3. Initialize the VM with Ansible over the provider bootstrap SSH path.
4. Converge the host to named `ansible` and `admin` users with locked passwords, `ssh-ed25519` authorized keys, and passwordless sudo.

```sh
mise run key:extract
mise run key:upload
mise run vm:create
mise run vm:init
```

SSH shortcuts:

```sh
mise run ssh:root
mise run ssh:ansible
mise run ssh:admin
```

## Ansible Shape

`roles/users` contains the idempotent host state. It creates users, installs authorized keys, grants passwordless sudo, and verifies sudo with Ansible modules where modules fit the job.

`playbooks/initialize.yml` is a thin entry point for the VM initialization path. It reads extracted public key files from environment variables and passes normal Ansible variables into the role.

`mise.toml` is contributor convenience only. It can call 1Password, DigitalOcean, and Ansible for local development, but provider and secret-manager behavior should not move into reusable collection roles.

The previous playbook-oriented prototype has been moved to:

```text
archive/playbook-prototype/
```

That archive remains useful reference material while the collection shape is rebuilt one piece at a time.

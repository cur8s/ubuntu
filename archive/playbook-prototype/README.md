# Cur8s Ubuntu

Cur8s Ubuntu is an Ansible-based Ubuntu host baseline.

The repository is intended to be reusable as a public project. Local secrets, private keys, generated public keys, and real host inventory stay outside git. The included `mise` tasks provide a small DigitalOcean test workflow so the baseline can be exercised on a disposable Ubuntu VM.

## Prerequisites

Install and authenticate these workstation tools:

* `op`
* `doctl`
* `ansible`
* `mise`

Enable the 1Password SSH agent on the workstation. The mise tasks create a local symlink at `.generated/ssh/1password-agent.sock` so OpenSSH and Ansible can address the agent through a path without spaces.

## 1Password Items

By default, the repo expects these SSH key items in the `Development` vault:

| Purpose | 1Password item | Field |
| --- | --- | --- |
| Provider bootstrap/root access | `cur8s-ubuntu-bootstrap` | `public key` |
| Ansible automation user | `ansible` | `public key` |
| Human admin user | `admin` | `public key` |

All three SSH public keys must be `ssh-ed25519` OpenSSH public keys.

The default lookup values live in `mise.toml`:

```toml
OP_BOOTSTRAP_SSH_KEY_VAULT = "Development"
OP_BOOTSTRAP_SSH_KEY_ITEM = "cur8s-ubuntu-bootstrap"
OP_BOOTSTRAP_SSH_PUBLIC_KEY_FIELD = "public key"
OP_ANSIBLE_SSH_KEY_VAULT = "Development"
OP_ANSIBLE_SSH_KEY_ITEM = "ansible"
OP_ANSIBLE_SSH_PUBLIC_KEY_FIELD = "public key"
OP_ADMIN_USER_SSH_KEY_VAULT = "Development"
OP_ADMIN_USER_SSH_KEY_ITEM = "admin"
OP_ADMIN_USER_SSH_PUBLIC_KEY_FIELD = "public key"
```

If your vault, item, or field names differ, update those values before running the tasks.

## DigitalOcean Test VM

Create a disposable Ubuntu test VM:

```sh
mise run test-vm-create
```

This renders the bootstrap public key from 1Password, registers it with DigitalOcean as `cur8s-ubuntu-bootstrap` when needed, then creates the Droplet with that SSH key. Passing the provider SSH key during Droplet creation avoids DigitalOcean's temporary root password flow.

Initialize the baseline users:

```sh
mise run test-vm-init
```

This creates:

* `ansible`, with passwordless sudo and its SSH public key
* `admin`, with passwordless sudo and its SSH public key

Validate direct SSH access:

```sh
mise run test-vm-ssh-ansible
mise run test-vm-ssh-admin
```

Converge the baseline:

```sh
mise run test-vm-converge
```

Delete the test VM:

```sh
mise run test-vm-delete
```

## Generated Files

Rendered public keys and local agent symlinks are written under `.generated/`. That directory is ignored by git.

## Documentation

* [Baseline playbooks](ansible/playbooks/baseline/README.md)
* [Cloud VM provisioning](docs/operations/provision-cloud-vm.md)
* [RFCs](docs/rfcs)

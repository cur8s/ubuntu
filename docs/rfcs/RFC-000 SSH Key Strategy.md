# RFC-000: SSH Key Strategy

Status: Draft

This repository defines a three-key SSH strategy for provisioning and initializing Ubuntu hosts.

The strategy separates provider bootstrap access from ongoing host administration. A provider-trusted bootstrap key creates the first SSH path to a newly provisioned host. Ansible then replaces that temporary provider bootstrap path with named non-root administrative users.

All SSH user access keys governed by this RFC must use the `ssh-ed25519` OpenSSH public key type. RSA, ECDSA, DSA, and other SSH public key types are not approved for baseline host access.

## Key Roles

The baseline uses three user access keys:

| 1Password item | Role | Installed host account | Purpose |
| --- | --- | --- | --- |
| `ubuntu-bootstrap` | Provider bootstrap key | Provider bootstrap account, temporarily | Creates the initial SSH path when the provider creates a VM |
| `ubuntu-ansible` | Automation key | `ansible` | Allows Ansible to manage the host using a named non-root account with sudo |
| `ubuntu-admin` | Human administrator key | `admin` | Allows a human administrator to access the host using a named non-root account with sudo |

The private key material for all three keys lives outside this repository in the `devops` 1Password vault. Private keys must not be committed, embedded into reusable templates, or written to generated repository files.

Public keys are distributable configuration. The contributor workflow may extract public keys from 1Password into ignored files under `.generated/` so they can be passed to a cloud provider, OpenSSH, and Ansible.

## Provider Bootstrap Key

The `ubuntu-bootstrap` key is trusted by the cloud provider and is used when creating a VM.

Cloud providers have different SSH key injection mechanisms, but the baseline model is the same: the provider receives the `ubuntu-bootstrap` public key at VM creation time and installs it into an initial bootstrap account on the new host.

The provider bootstrap key exists to solve exactly one problem: making the first Ansible connection possible.

It is not the normal administration key for a converged host. It is also not inherently a root key. Some providers use `root`, while others use an image-defined or caller-defined non-root account with sudo.

## Provider Bootstrap Accounts

The bootstrap account is provider-specific:

| Provider | Creation-time key mechanism | Bootstrap account model |
| --- | --- | --- |
| DigitalOcean | Droplet SSH key ID or fingerprint | `root` on the initial Ubuntu Droplet |
| AWS EC2 | EC2 key pair referenced by `--key-name` | AMI-defined default user; Ubuntu AMIs use `ubuntu` |
| Google Compute Engine | Instance metadata `ssh-keys` entry | Username embedded in metadata, such as `bootstrap:ssh-ed25519 ...` |
| Azure VM | `az vm create --admin-username` with `--ssh-key-values` or `--ssh-key-name` | Caller-defined admin username, such as `bootstrap` |

The provider bootstrap account must have a path to privilege escalation so Ansible can initialize the host. For DigitalOcean this is root access. For AWS, GCP, and Azure this is normally a non-root account with passwordless or non-interactive sudo.

The baseline must not assume root SSH is available across providers.

## Initialization Flow

A newly provisioned host is initialized through this sequence:

1. The contributor workflow extracts the three public keys from 1Password.
2. The contributor workflow creates a VM with the provider-specific SSH key injection mechanism for `ubuntu-bootstrap`.
3. Ansible connects to the new host through the provider bootstrap account.
4. Ansible creates the `ansible` user with a locked password, an `ssh-ed25519` authorized key from `ubuntu-ansible`, and passwordless sudo.
5. Ansible creates the `admin` user with a locked password, an `ssh-ed25519` authorized key from `ubuntu-admin`, and passwordless sudo.
6. The workflow proves that both `ansible` and `admin` can connect over SSH and run non-interactive sudo.
7. After both named users are proven, Ansible removes the provider bootstrap key from the provider bootstrap account.

The steady-state baseline does not rely on provider bootstrap SSH access.

## Provider Registration

Removing the bootstrap key from a host does not require removing the key from the provider.

The `ubuntu-bootstrap` public key may remain registered with the provider so future VMs can be created without password bootstrap. Provider-side registration only allows the key to be injected into newly created hosts. It does not preserve access to an already-initialized host once the key has been removed from that host's bootstrap account.

Provider-side cleanup is optional and provider-specific. Host-side cleanup is mandatory for the steady-state baseline.

## Collection Boundary

The Ansible collection must not depend directly on a cloud provider or 1Password.

The collection is responsible for idempotently managing Ubuntu host state:

* validating that provided SSH public keys are `ssh-ed25519`
* creating named users
* locking password authentication for those users
* installing authorized SSH public keys
* granting passwordless sudo
* removing the provider bootstrap key from the provider bootstrap account once replacement access is proven

The contributor workflow is responsible for environment-specific orchestration:

* reading public keys from 1Password
* registering or selecting the provider SSH key
* creating and deleting test VMs
* passing extracted public keys and target host details into Ansible

This separation keeps the collection reusable while still giving contributors a one-command development workflow.

## Ansible Conventions

The initialization behavior should be implemented as idempotent Ansible role logic with a thin playbook entry point.

The role should accept public keys and the bootstrap account name as variables or file-derived values rather than invoking `op`, `doctl`, `aws`, `gcloud`, or `az` itself. Tasks should use Ansible modules such as `ansible.builtin.user`, `ansible.builtin.copy`, and `ansible.posix.authorized_key` instead of shell commands when those modules express the desired state directly.

Validation is part of the desired behavior. The role or workflow must fail before making unsafe changes when required keys are missing or are not `ssh-ed25519` public keys.

The bootstrap key must not be removed until replacement access for the named users has been proven.

## Scope

This RFC defines the SSH key roles and lifecycle for initial host access.

It does not define the full OpenSSH server hardening policy, Ubuntu package maintenance, inventory structure, exact role names, cloud account configuration, 1Password item field names, key rotation procedures, or host recovery procedures.

This RFC governs OpenSSH public keys, not OpenSSH user certificates.

## Revisions

Initial draft.

Reframed the bootstrap key as provider-neutral temporary access rather than DigitalOcean-specific root access.

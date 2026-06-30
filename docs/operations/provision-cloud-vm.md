# Provision A Cloud VM

The DigitalOcean test VM is provisioned with DigitalOcean SSH key metadata.

The administrator SSH private key stays in 1Password. The administrator SSH public key is rendered from 1Password for Ansible convergence.

The Tailscale auth key also stays in 1Password. The converge task reads it into the process-local `TAILSCALE_AUTHKEY` environment variable before Ansible starts. It is not written to a generated file.

The create task passes `--ssh-keys "$DO_SSH_KEY_ID"`. This provider-specific metadata prevents DigitalOcean from creating a temporary root password and forcing an interactive password change on first login.

The registered DigitalOcean public key should match the administrator public key rendered from 1Password. DigitalOcean's metadata gets the first SSH connection working; Ansible enforces the final administrator key during baseline convergence.

The default 1Password lookup is configured in `mise.toml`:

```toml
OP_ADMIN_SSH_KEY_VAULT = "Development"
OP_ADMIN_SSH_KEY_ITEM = "cur8s-ubuntu-lab"
OP_ADMIN_SSH_PUBLIC_KEY_FIELD = "public key"
DO_SSH_KEY_ID = "57436897"
TAILSCALE_TEST_VM_HOST = "cur8s-ubuntu-test.puma-mora.ts.net"
OP_TAILSCALE_AUTHKEY_VAULT = "Development"
OP_TAILSCALE_AUTHKEY_ITEM = "ubuntu-tailscale-auth-key"
OP_TAILSCALE_AUTHKEY_FIELD = "password"
```

Override these environment values if the 1Password vault, item, or field names differ on your workstation.

Render the administrator SSH public key:

```sh
mise run render-admin-ssh-public-key
```

The converge task also runs this render step automatically.

Create the test VM:

```sh
mise run test-vm-create
```

Converge the baseline, including administrator SSH key enforcement and Tailscale join when needed:

```sh
mise run test-vm-converge
```

Test Tailscale SSH:

```sh
mise run test-vm-tailscale-ssh
```

This task uses OpenSSH against the Tailscale MagicDNS name and disables public key, password, and keyboard-interactive authentication so the check proves Tailscale SSH is handling access.

Rendered files are written under `.generated/` and are not committed.

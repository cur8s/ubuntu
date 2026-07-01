# Provision A Cloud VM

The DigitalOcean test VM is provisioned with DigitalOcean SSH key metadata.

The provider bootstrap SSH private key stays in 1Password. The matching public key is registered with DigitalOcean and is used only to make the first root connection possible.

The `ansible` and `admin` SSH private keys also stay in 1Password. Their public keys are rendered from 1Password and installed during host initialization.

The provider bootstrap, `ansible`, and `admin` SSH public keys must all use the `ssh-ed25519` OpenSSH public key type.

The SSH test commands use the rendered public keys as OpenSSH identity hints. They also create a local symlink at `.generated/ssh/1password-agent.sock` so OpenSSH can address the 1Password SSH agent without the space in the macOS `Group Containers` path.

The create task passes `--ssh-keys "$DO_SSH_KEY_ID"`. This provider-specific metadata prevents DigitalOcean from creating a temporary root password and forcing an interactive password change on first login.

The registered DigitalOcean public key should match the provider bootstrap public key rendered from 1Password. DigitalOcean's metadata gets the first SSH connection working; Ansible then initializes the durable `ansible` and `admin` access paths.

The default 1Password lookup is configured in `mise.toml`:

```toml
OP_ADMIN_SSH_KEY_VAULT = "Development"
OP_ADMIN_SSH_KEY_ITEM = "cur8s-ubuntu-lab"
OP_ADMIN_SSH_PUBLIC_KEY_FIELD = "public key"
OP_ANSIBLE_SSH_KEY_VAULT = "Development"
OP_ANSIBLE_SSH_KEY_ITEM = "ansible"
OP_ANSIBLE_SSH_PUBLIC_KEY_FIELD = "public key"
OP_ADMIN_USER_SSH_KEY_VAULT = "Development"
OP_ADMIN_USER_SSH_KEY_ITEM = "admin"
OP_ADMIN_USER_SSH_PUBLIC_KEY_FIELD = "public key"
DO_SSH_KEY_ID = "57436897"
```

Override these environment values if the 1Password vault, item, or field names differ on your workstation.

Render the SSH public keys used during initialization:

```sh
mise run render-initialize-ssh-public-keys
```

The init task also runs this render step automatically.

Create the test VM:

```sh
mise run test-vm-create
```

Initialize the host:

```sh
mise run test-vm-init
```

The init task runs as `root` over the provider-created bootstrap SSH path. It creates the `ansible` and `admin` users, installs their SSH public keys, configures passwordless sudo, and validates that both users can connect with SSH and run non-interactive sudo.

Test the initialized SSH access paths directly:

```sh
mise run test-vm-ssh-ansible
mise run test-vm-ssh-admin
```

Converge the baseline after initialization:

```sh
mise run test-vm-converge
```

The converge task is the steady-state path and does not reboot the host. It still runs as `root` until the initialized `ansible` user has been proven on the test VM; the next step is to switch convergence to `--user ansible --become`.

Test Tailscale SSH:

```sh
mise run test-vm-install-tailscale
mise run test-vm-join-tailscale
mise run test-vm-tailscale-ssh
```

These optional example tasks install Tailscale, join the host to the tailnet, and then use OpenSSH against the Tailscale MagicDNS name with public key, password, and keyboard-interactive authentication disabled so the check proves Tailscale SSH is handling access. The join task reads the Tailscale auth key from the `OP_TAILSCALE_AUTHKEY_*` values in `mise.toml`.

Rendered files are written under `.generated/` and are not committed.

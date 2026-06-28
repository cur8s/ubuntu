# DigitalOcean Lab VMs

The lab scripts create disposable DigitalOcean Droplets for testing this repository against a fresh Ubuntu host.

## Setup

Authenticate `doctl` first:

```sh
doctl auth init --context default
doctl account get
```

Create local lab configuration:

```sh
./bin/lab-vm init
```

Edit `.state/digitalocean.env` if the default region, image, size, Droplet name, or SSH key path should change.

## SSH Key

The lab workflow uses SSH keys by default. The private key stays on this machine under `~/.ssh`; DigitalOcean receives only the public key.

Generate and import the configured key:

```sh
./bin/lab-vm init-key
```

By default this creates:

```text
~/.ssh/cur8s-ubuntu-lab_ed25519
~/.ssh/cur8s-ubuntu-lab_ed25519.pub
```

The public key is imported into DigitalOcean with the name from `DO_SSH_KEY_NAME`.

To use an existing key instead, set these in `.state/digitalocean.env`:

```sh
DO_SSH_KEY_NAME=my-existing-key-name
DO_SSH_KEY_PATH="${HOME}/.ssh/id_ed25519"
```

Then run:

```sh
./bin/lab-vm init-key
```

## Workflow

Create a test VM:

```sh
./bin/lab-vm create
```

Copy the repo to the VM:

```sh
./bin/lab-vm sync
```

Run the bootstrap:

```sh
./bin/lab-vm bootstrap --profile base
```

Run verification:

```sh
./bin/lab-vm check --profile base
```

Open SSH:

```sh
./bin/lab-vm ssh
```

Destroy the test VM:

```sh
./bin/lab-vm destroy --force
```

## Safety

`.state/` is ignored by git and holds local configuration plus the current Droplet ID/IP.

The lab wrapper uses key-based SSH and `ssh_pwauth: false` in cloud-init. Password-authenticated VMs should be treated as an explicit unsafe test case, not the default workflow.

# Ubuntu Production Bootstrap

This repository contains scripts and supporting tools for turning a fresh Ubuntu 24.04 LTS install into a hardened production baseline. It is intended for clean Ubuntu environments that should all look the same before application-specific repos take over.

The baseline covers system updates, security hardening, SSH, firewalling, Tailscale connectivity, osquery visibility, and verification checks. It intentionally does not install workload runtimes or applications; those belong in separate repos.

## Usage

Run the bootstrap entrypoint on a fresh Ubuntu host:

```sh
sudo env TAILSCALE_AUTHKEY=tskey-auth-... ./bin/ubuntu-bootstrap
```

If you use `mise`, the repository adds `bin/` and `tests/` to PATH when the environment is activated:

```sh
mise trust
sudo env TAILSCALE_AUTHKEY=tskey-auth-... ubuntu-bootstrap
```

The bootstrap applies one opinionated baseline in a fixed order.

Run verification checks without applying changes:

```sh
sudo ./bin/ubuntu-check
```

For disposable DigitalOcean VM testing, use the lab wrapper:

```sh
lab-vm init
lab-vm init-key
lab-vm create
lab-vm bootstrap
lab-vm check
lab-vm destroy --force
```

See `lab/README.md` for the SSH key and Droplet workflow.

## Repository Layout

- `bin/`: user-facing entrypoints.
- `lib/common.sh`: small shared shell primitives.
- `docs/`: project policy and operational notes.
- `lab/`: local DigitalOcean lab VM configuration and cloud-init templates.
- `tests/`: local syntax and smoke checks for this repository.

See `docs/support-policy.md` and `docs/third-party-apt-repos.md` for the package and operating system policies that guide baseline design.

## Philosophy

The goal of this project is to provide a stable, repeatable foundation for building and running applications. It is not a place to evaluate the latest operating system releases.

The baseline targets Ubuntu 24.04 LTS (`noble`). Hosts running another Ubuntu release fail preflight instead of receiving a partial or best-effort setup.

This project optimizes for boring infrastructure. Security updates and point releases should be applied promptly, but major operating system upgrades are intentionally deferred until the next LTS has been released and the ecosystem has stabilized. The intended result is fewer surprises, lower maintenance overhead, and more time spent developing applications instead of troubleshooting operating system compatibility issues.

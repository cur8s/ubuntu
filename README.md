# Ubuntu Production Bootstrap

This repository contains scripts and supporting tools for turning a fresh Ubuntu install into a production-ready host. It is intended for newly launched cloud VMs, bare-metal servers, and other clean Ubuntu environments that need a consistent baseline before running workloads.

The project will collect repeatable setup steps for system updates, security hardening, users and access, networking, observability, runtime dependencies, and operational checks.

## Usage

Run the bootstrap entrypoint on a fresh Ubuntu host:

```sh
sudo ./bin/ubuntu-bootstrap --profile base
```

Profiles live in `profiles/` and select the modules that should be applied to a host. The default `base` profile is intentionally conservative; cloud, bare-metal, and k3s-oriented profiles can enable additional modules such as Tailscale and osquery.

Run verification checks without applying changes:

```sh
sudo ./bin/ubuntu-check --profile base
```

For disposable DigitalOcean VM testing, use the lab wrapper:

```sh
./bin/lab-vm init
./bin/lab-vm init-key
./bin/lab-vm create
./bin/lab-vm bootstrap --profile base
./bin/lab-vm check --profile base
./bin/lab-vm destroy --force
```

See `lab/README.md` for the SSH key and Droplet workflow.

## Repository Layout

- `bin/`: user-facing entrypoints.
- `lib/`: shared shell helpers for logging, APT, systemd, and checks.
- `profiles/`: host profiles that choose modules and phase order.
- `phases/`: ordered lifecycle steps run by the bootstrap entrypoint.
- `modules/`: idempotent units of setup such as SSH, firewall, Tailscale, and osquery.
- `docs/`: project policy and operational notes.
- `lab/`: local DigitalOcean lab VM configuration and cloud-init templates.
- `tests/`: local syntax and smoke checks for this repository.

See `docs/support-policy.md` and `docs/third-party-apt-repos.md` for the package and operating system policies that guide module design.

## Philosophy

The goal of this project is to provide a stable, repeatable foundation for building and running applications. It is not a place to evaluate the latest operating system releases.

The baseline targets the previous Ubuntu LTS rather than the current one. This gives the broader ecosystem, including Kubernetes, k3s, container runtimes, security tools, drivers, and third-party packages, time to mature before it becomes part of the platform.

This project optimizes for boring infrastructure. Security updates and point releases should be applied promptly, but major operating system upgrades are intentionally deferred until the next LTS has been released and the ecosystem has stabilized. The intended result is fewer surprises, lower maintenance overhead, and more time spent developing applications instead of troubleshooting operating system compatibility issues.

# Modules

Modules are idempotent units of host setup. A module may implement any of these scripts:

- `repo.sh`: add official package repositories and scoped keyrings.
- `install.sh`: install operating system packages.
- `configure.sh`: write configuration and manage services.
- `verify.sh`: check that the expected files, commands, packages, and services exist.

The baseline runs a fixed module list through `UBUNTU_BOOTSTRAP_MODULES`. Repository setup is limited to modules listed in `UBUNTU_BOOTSTRAP_REPO_MODULES`.

Keep module scripts narrow. A Tailscale module should not harden SSH, and an SSH module should not manage firewall rules.

# Third-Party APT Repositories

Third-party APT repositories are allowed, but they should be treated as an explicit trust decision.

Each repository-backed package should have a simple installer under `install/`, be called explicitly from `bin/ubuntu-bootstrap`, and be verified in `bin/ubuntu-check`.

## Rules

- Use the vendor's official repository and package documentation.
- Install keyrings under `/usr/share/keyrings`.
- Use `signed-by=` in `/etc/apt/sources.list.d/*.list`.
- Do not use the legacy global `apt-key` trust store.
- Keep each package installer small enough to audit at a glance.

## Current Examples

Tailscale uses Tailscale's Ubuntu package repository under `https://pkgs.tailscale.com`.

osquery uses osquery's Debian package repository under `https://pkg.osquery.io/deb`.

Lynis uses CISOfy's community Debian package repository under `https://packages.cisofy.com/community/lynis/deb/`.

When adding a new repository-backed package, keep the install script and verification close to the rest of the baseline so the trust decision is easy to audit.

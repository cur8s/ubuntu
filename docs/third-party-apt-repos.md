# Third-Party APT Repositories

Third-party APT repositories are allowed, but they should be treated as an explicit trust decision.

Each repository-backed package should be implemented as a module with this lifecycle:

```text
repo.sh       # install scoped keyring and source list
install.sh    # install packages from apt
configure.sh  # configure files and services
verify.sh     # prove the package and service are present
```

## Rules

- Use the vendor's official repository and package documentation.
- Install keyrings under `/usr/share/keyrings`.
- Use `signed-by=` in `/etc/apt/sources.list.d/*.list`.
- Do not use the legacy global `apt-key` trust store.
- Keep repository setup separate from package installation.
- Allow repo URLs, key URLs, suites, and components to be overridden by explicit environment variables when a module needs that flexibility.

## Current Examples

The `tailscale` module uses Tailscale's Ubuntu package repository under `https://pkgs.tailscale.com`.

The `osquery` module uses osquery's Debian package repository under `https://pkg.osquery.io/deb`.

When adding a new repository-backed package, follow the same module contract before enabling it in the baseline.

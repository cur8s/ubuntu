# Support Policy

## Ubuntu Baseline

The project targets Ubuntu 24.04 LTS (`noble`) as its production baseline.

The preflight phase rejects non-Ubuntu hosts and Ubuntu releases other than `noble`. This repo should fail loudly instead of trying to adapt itself to a different platform.

## Updates

Security updates and point releases should be applied promptly through the normal Ubuntu package channels.

Major operating system upgrades should be planned work. They should not happen as a side effect of a bootstrap run.

## Third-Party Packages

Third-party packages may be used when they are operationally important and come from a source we can audit. Each third-party package should have a small installer under `install/` and should document:

- The official upstream package source.
- The APT keyring and source list it installs.
- The package names it installs.
- The services it starts or enables.
- The verification checks that prove it is working.

# Support Policy

## Ubuntu Baseline

The project targets the previous Ubuntu LTS as its production baseline. This keeps the platform behind the newest major operating system release while still receiving long-term security support.

`UBUNTU_TARGET_CODENAME` may be set to enforce a specific Ubuntu codename. When the value is unset, the preflight phase verifies that the host is Ubuntu but does not reject a specific codename.

## Updates

Security updates and point releases should be applied promptly through the normal Ubuntu package channels.

Major operating system upgrades should be planned work. They should not happen as a side effect of a bootstrap run.

## Third-Party Packages

Third-party packages may be used when they are operationally important and come from a source we can audit. Each third-party package should live in its own module and should document:

- The official upstream package source.
- The APT keyring and source list it installs.
- The package names it installs.
- The services it starts or enables.
- The verification checks that prove it is working.

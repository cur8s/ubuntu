# Examples

Runnable, copy-paste-able examples of consuming `cur8s.ubuntu`. Each example
is a self-contained directory: a `site.yml` that enforces the baseline
first (the composition pattern every layer follows — RFC-001: The Host
Baseline) and then applies its layer, plus a README naming the techniques it
demonstrates. Examples are layers, so unlike baseline roles they may verify
their own outcomes in-play (RFC-002: Baseline Doctrine).

Every example must work on both supported architectures, amd64 and arm64
(RFC-010: Release and Versioning): repo lines declare both architectures,
and release binaries are selected through an architecture map (see
`zot/`). Nothing may assume an architecture it did not detect.

The catalog is deliberately small: three examples that each demonstrate
a distinct technique set, with no technique shown twice. Patterns the
catalog does not demonstrate live in the user guide's "Installing deb
packages" reference (docs/guides/user-guide.md).

## Index

| Example | Theme | Techniques demonstrated |
| --- | --- | --- |
| `site.yml` (this dir) | composition | minimal consumer playbook: baseline import + your plays |
| `docker/` | containers | vendor apt repo (deb822 `.sources` + `Signed-By` keyring), multi-package install, service + validation |
| `zot/` | containers | GitHub release binary → system user/dirs → config from vars → hand-written systemd unit + handlers |
| `tailscale/` | access | vendor-hosted keyring/list, secret input via env var (`no_log`), stateful idempotent join |

## Running the examples (contributors)

The local QEMU lab must exist (`mise run qemu:up`; see
`docs/guides/developer-guide.md`). Examples resolve `cur8s.ubuntu` from the
working tree via a symlink under `.generated/` — created automatically — so
role edits are picked up without committing or reinstalling:

```sh
mise run qemu:test:docker   # one example, on the local lab
mise run qemu:test:all      # every example (skips tailscale without TAILSCALE_AUTHKEY)
```

Every `test:` task enforces the examples' contract: it runs the example
twice and fails unless the second pass reports `changed=0` end to end
(baseline no-op + idempotent layer). At release cadence the same suite
runs on real amd64 via `mise run test:integration:digital-ocean-examples`
(the DigitalOcean integration folder's droplet must be up).

## Using from your own repository (consumers)

Install the collection from git, then copy the example directory you want
into your environment repository as a starting point:

```sh
ansible-galaxy collection install -r requirements.yml
ANSIBLE_PUB_KEY=/path/to/ubuntu-ansible.pub \
SYSADMIN_PUB_KEY=/path/to/ubuntu-sysadmin.pub \
ansible-playbook -i <host-ip>, docker/site.yml
```

The environment-variable inputs are the stable consumer surface (RFC-011:
Conventions Contract).

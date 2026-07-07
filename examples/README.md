# Examples

Runnable, copy-paste-able examples of consuming `cur8s.ubuntu`. Each example
is a self-contained directory: a `site.yml` that enforces the baseline
first (the composition pattern every layer follows — RFC-001: The Host
Baseline) and then applies its layer, plus a README naming the techniques it
demonstrates. Examples are layers, so unlike baseline roles they may verify
their own outcomes in-play (RFC-002: Baseline Doctrine).

Every example must work on both supported architectures, amd64 and arm64
(RFC-010: Release and Versioning): repo lines declare both architectures,
and release binaries are selected by the detected architecture (see
`zot/`). Nothing may assume an architecture it did not detect.

The catalog is deliberately small: three examples that each demonstrate
a distinct technique set, with no technique shown twice. Patterns the
catalog does not demonstrate live in the user guide's "Installing deb
packages" reference (docs/guides/user-guide.md). A new example earns
its place only by demonstrating a technique the catalog does not
already show; anything else belongs in that reference.

## Index

| Example | Theme | Techniques demonstrated |
| --- | --- | --- |
| `site.yml` (this dir) | composition | minimal consumer playbook: baseline import + your plays |
| `docker/` | containers | vendor apt repo (deb822 `.sources` + `Signed-By` keyring), multi-package install, service + validation |
| `zot/` | containers | GitHub release binary → system user/dirs → config from vars → hand-written systemd unit + handlers |

The access-layer demo (tailscale) lives beside the operator's cloud
custody: verifying it needs a real tailnet and a secret, which the
local proof plane deliberately excludes. Its techniques worth stealing:
secret input via an env var with `no_log`, and probe-state-before-acting
idempotent joins.

## Running the examples (contributors)

The local QEMU lab must exist (`mise run up`; see
`docs/guides/developer-guide.md`). Examples resolve `cur8s.ubuntu` from the
working tree via a symlink under `.generated/` — created automatically — so
role edits are picked up without committing or reinstalling:

```sh
mise run test:docker   # one example, on the local lab
mise run test:all      # every example
```

Every `test:` task enforces the examples' contract: it runs the example
twice and fails unless the second pass reports `changed=0` end to end
(baseline no-op + idempotent layer). The same suite runs on amd64 in CI
on every push (`.github/workflows/ci.yml` — the lab's guest arch
follows the host), so both promised architectures are proven
continuously.

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

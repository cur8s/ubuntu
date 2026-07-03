# Examples

Runnable, copy-paste-able examples of consuming `cur8s.ubuntu`. Each example
is a self-contained directory: a `site.yml` that re-asserts the baseline
first (the composition pattern every layer follows — RFC-001: The Host
Baseline) and then applies its layer, plus a README naming the techniques it
demonstrates. Examples are layers, so unlike baseline roles they may verify
their own outcomes in-play (RFC-002: Baseline Doctrine).

Every example must work on both supported architectures, amd64 and arm64
(RFC-008: Release and Versioning): repo lines declare both architectures,
release binaries are selected through an architecture map (see `zot/`), and
installers that detect the architecture themselves (see `k3s/`) are
preferred. Nothing may assume an architecture it did not detect.

## Index

| Example | Theme | Techniques demonstrated | Status |
| --- | --- | --- | --- |
| `site.yml` (this dir) | composition | minimal consumer playbook: baseline import + your plays | ported |
| `docker/` | containers | vendor apt repo (deb822 `.sources` + `Signed-By` keyring), multi-package install, service + validation | ported |
| `postgres/` | database | versioned vendor package from PGDG, deb822 repo | ported |
| `zot/` | containers | GitHub release binary → system user/dirs → config from vars → hand-written systemd unit + handlers | ported |
| `lynis/` | security | ASCII key → `gpg --dearmor` keyring → classic `.list` repo; package with no service | ported |
| `osquery/` | security | install a package but keep its daemon deliberately off (interactive-only tooling) | ported |
| `tailscale/` | access | vendor-hosted keyring/list, secret input via env var (`no_log`), stateful idempotent join | ported |
| `k3s/` | kubernetes | vendor installer piped to `sh` made idempotent (channel resolve + version gate), env-var installer params, declarative `config.yaml`, node-Ready wait | ported |

## Running against a lab VM (contributors)

The target lab must exist — the droplet or the local QEMU VM (see
`docs/operations/manual.md`). Examples resolve `cur8s.ubuntu` from the
working tree via a symlink under `.generated/` — created automatically — so
role edits are picked up without committing or reinstalling:

```sh
mise run example:run docker          # the droplet (target do, the default)
mise run example:run docker qemu    # the local QEMU VM
```

Run an example twice: the second run should report `changed=0` end to end
(baseline no-op + idempotent layer). `mise run example:run-all [target]`
enforces exactly that across every example (skipping `tailscale` unless
`TAILSCALE_AUTHKEY` is set).

## Using from your own repository (consumers)

Install the collection from git, then copy the example directory you want
into your environment repository as a starting point:

```sh
ansible-galaxy collection install -r requirements.yml
ANSIBLE_PUB_KEY=/path/to/ubuntu-ansible.pub \
SYSADMIN_PUB_KEY=/path/to/ubuntu-sysadmin.pub \
ansible-playbook -i <host-ip>, docker/site.yml
```

The environment-variable inputs are the stable consumer surface (RFC-009:
Conventions Contract).

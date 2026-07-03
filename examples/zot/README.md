# Example: zot OCI registry

Installs the [zot](https://zotregistry.dev/) OCI registry from a GitHub
release binary and runs it as a systemd service, layered on the baseline.
This is the "no package, just a binary" pattern.

Techniques demonstrated:

- **Release binary install** — `get_url` from a GitHub release, with a dpkg
  architecture → release architecture mapping.
- **Dedicated system user/group** (`nologin`, no home) and a service
  directory layout (config, data, logs) with correct ownership.
- **Config rendered from a structured var** — the config lives as YAML in
  the play and lands as JSON via `to_nice_json`, so the play is the single
  source of truth.
- **Hand-written systemd unit** with resource limits, installed via `copy` +
  `daemon_reload`.
- **Handler-driven restarts** on binary/config/unit change, config `verify`
  before enable, and an API smoke test (`/v2/`) with retries.

Run against the lab VM (droplet must exist — see the operations manual):

```sh
mise run do:example zot
```

The first play re-asserts the baseline (RFC-001); the second installs zot.
Run it twice: the second run should report `changed=0` end to end.

Two pitfalls this example encodes, both found by running it:

- **zot initializes its log file on any invocation, `verify` included.** If
  verify runs as root before the service ever starts, the log is created
  root-owned and the service (running as `zot`) crash-loops with
  `panic: open /var/log/zot/zot.log: permission denied`. The play
  pre-creates the log with service ownership (idempotent touch) so verify
  can run as root — avoiding `become_user` to a `nologin` system user,
  which needs the `acl` package the baseline does not pin.
- **`systemctl is-active` races handler restarts** — the unit reads
  `activating` for a moment; the check retries until it settles, and the
  API smoke test is the real readiness proof.

The prototype's homelab-sized `MemoryHigh`/`MemoryMax` clamps were dropped.

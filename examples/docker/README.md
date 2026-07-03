# Example: Docker Engine

Installs Docker Engine from Docker's own apt repository, layered on the
baseline.

Techniques demonstrated:

- **Vendor apt repository, deb822 style** — a `.sources` file in
  `/etc/apt/sources.list.d/` with a `Signed-By:` keyring downloaded to
  `/etc/apt/keyrings/`, scoped to the host's dpkg architecture.
- **Multi-package install** from the vendor repo (`docker-ce`, CLI,
  containerd, buildx, compose plugin).
- **Service enable/start with in-play validation** — layers may verify
  outcomes in-play (unlike baseline roles; see RFC-002: Baseline Doctrine).

Run against the lab VM (droplet must exist — see the operations manual):

```sh
mise run do:example docker
```

The first play re-asserts the baseline (the composition pattern every layer
follows — RFC-001); the second installs Docker. Run it twice: the second run
should report `changed=0` end to end.

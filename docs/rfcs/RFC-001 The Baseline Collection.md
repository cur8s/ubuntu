RFC-001: The Baseline Collection

Status: Accepted

This repository is `baseline.ubuntu`: an Ansible collection that defines the floor every managed Ubuntu host gets, regardless of what runs on top.

The floor is a known, hardened, reproducible starting state. Every host begins from the same baseline, on any provider, with conventions that higher-level automation can rely on. A host either conforms to the floor or it does not. If a host came from this collection, it is fit for production; the collection is the reproducible path, with no snowflake steps.

**Composition**

The architecture has three tiers.

`baseline.ubuntu` — this repository — is the generic bottom tier: the floor plus the parameterized mechanisms that apply it. It holds no secrets, no inventory, and no schedule.

Use-case collections (for example `baseline.k3s`) depend on `baseline.ubuntu`. Their converge calls the baseline converge first, re-asserting the floor, and then applies their own purpose.

Environment repositories are a consumer's deployment. They pull in the use-case collections, hold the inventory, host specifics, and keys, and run converge ad-hoc or on a schedule.

Because every tier re-asserts `baseline.ubuntu`, the floor is guaranteed on every host, on every converge.

Access layers follow the same pattern. An identity-aware management network is a separate opt-in collection, never baked into the baseline: the floor must stay access-agnostic and work without one. A sketch is held in `docs/examples/management-network.md`.

**The Repository**

This repository contains the collection and a contributor test harness — the `mise` workflow that exercises the collection against a disposable cloud VM. The harness may call cloud providers and a secrets manager; the collection itself must not. Everything needed to develop, verify, release, and consume the collection is self-contained here: architecture in `docs/rfcs/`, operations in `docs/operations/manual.md`, runnable consumption examples in `examples/`.

**Non-Goals**

The baseline does not build golden images, provision infrastructure with IaC tooling, run per-host agents or self-healing daemons, define network perimeters or firewall policy, configure workloads, or define specific human users. Those concerns belong to layers, environment repositories, or the provider.

**Scope**

This RFC defines what `baseline.ubuntu` is, the three-tier composition model, and the boundary between the collection and the repository around it.

It does not define what qualifies for the floor (RFC-002: Floor Doctrine), the floor's contents (RFC-003: Floor Contents), or how hosts are provisioned and converged (RFC-005: Provisioning, RFC-006: Convergence).

**Revisions**

Initial version.

# RFC-001: The Host Baseline

Status: Accepted

This repository defines a Host Baseline for Ubuntu Server systems: the floor every managed host gets, regardless of what runs on top.

The Host Baseline is a known, hardened, reproducible starting state. Every host begins from the same baseline, on any provider, with conventions that higher-level automation can rely on. A host either conforms to the baseline or it does not. If a host came from this baseline, it is fit for production; the baseline is the reproducible path, with no snowflake steps.

## Lifecycle

A host is provisioned once and converged forever. Provisioning produces a reachable host that already conforms (RFC-005: Provisioning). Convergence re-asserts the declared state for the rest of the host's life, reverting drift (RFC-006: Convergence). Later RFCs use "converge" in this sense.

## The Floor and Layers

The baseline is a two-tier model. The immovable floor is a fixed set of invariants: always enforced, never turned off, re-asserted on every converge on every host. Layers are everything optional or overridable — workload software, network posture, access systems. Being disable-able is what makes something a layer. Layers add posture; the floor is minimal.

## Composition

Purposes stack on the floor in three tiers. The baseline is the generic bottom tier: it holds no secrets, no inventory, and no schedule. Purpose layers — a Kubernetes node, a database host — build on the baseline, and their convergence re-asserts the floor before applying their own purpose. Deployments are the top tier: they own the inventory, host specifics, and keys, and run convergence ad-hoc or on a schedule.

Because every tier re-asserts the baseline, the floor is guaranteed on every host, on every converge.

Access layers follow the same pattern. An identity-aware management network is an opt-in layer, never baked into the baseline: the floor must stay access-agnostic and work without one. A sketch is held in `docs/examples/management-network.md`.

## Non-Goals

The baseline does not build golden images, provision infrastructure with IaC tooling, run per-host agents or self-healing daemons, define network perimeters or firewall policy, configure workloads, or define specific human users. Those concerns belong to layers, deployments, or the provider.

## Scope

This RFC establishes the Host Baseline: its purpose, the floor-and-layers model, the lifecycle vocabulary, and the composition tiers.

It does not define what qualifies for the floor (RFC-002: Floor Doctrine), the floor's contents (RFC-003: Floor Contents), the lifecycle mechanics (RFC-005: Provisioning, RFC-006: Convergence), or how the baseline is packaged and distributed (RFC-008: Release and Versioning).

## Revisions

Initial version.

Rewritten concept-first as The Host Baseline; packaging moved to RFC-008 and repository orientation to the README.

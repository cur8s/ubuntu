# RFC-001: The Host Baseline

Status: Accepted

This repository defines a Host Baseline for Ubuntu Server systems: the invariant state every managed host gets, regardless of what runs on top.

The Host Baseline is a known, hardened, reproducible starting state. Every host begins from the same baseline, on any provider, with conventions that higher-level automation can rely on. A host either conforms to the baseline or it does not. If a host came from this baseline, it is fit for production; the baseline is the reproducible path, with no snowflake steps.

## Lifecycle

A host is provisioned once and converged forever. Provisioning produces a reachable host that already conforms (RFC-006: Provisioning). Convergence enforces the declared state for the rest of the host's life, reverting drift (RFC-008: Convergence). Later RFCs use "converge" in this sense.

## The Baseline and Layers

The model has two tiers. The baseline is a fixed set of invariants: always enforced, never turned off, enforced anew on every converge on every host. Layers are everything optional or overridable — workload software, network posture, access systems. Being disable-able is what makes something a layer. Layers add posture; the baseline is minimal.

The baseline is a floor: layers build above it, and nothing ever goes below it.

## Composition

Purposes stack on the baseline in three tiers. The baseline is the generic bottom tier: it holds no secrets, no inventory, and no schedule. Purpose layers — a Kubernetes node, a database host — build on the baseline, and their convergence enforces the baseline before applying their own purpose. Deployments are the top tier: they own the inventory, host specifics, and keys, and run convergence ad-hoc or on a schedule.

Because every tier enforces it, the baseline is guaranteed on every host, on every converge.

Access layers follow the same pattern. An identity-aware management network is an opt-in layer, never baked into the baseline, which must stay access-agnostic and work without one. A design sketch is held in `docs/notes/management-network.md`; the runnable technique demo lives beside the operator's cloud custody — verifying it needs a real tailnet and a secret, which this repository's proof plane deliberately excludes.

## Non-Goals

The baseline does not build golden images, provision infrastructure with IaC tooling, run per-host agents or self-healing daemons, define network perimeters or firewall policy, configure workloads, or define specific human users. Those concerns belong to layers, deployments, or the provider.

## Scope

This RFC establishes the Host Baseline: its purpose, the baseline-and-layers model, the lifecycle vocabulary, and the composition tiers.

It does not define what qualifies for the baseline (RFC-002: Baseline Doctrine), its contents (RFC-003: Baseline Contents), the lifecycle mechanics (RFC-006: Provisioning, RFC-008: Convergence), or how the baseline is packaged and distributed (RFC-010: Release and Versioning).

## Revisions

Initial version.

Rewritten concept-first as The Host Baseline; packaging moved to RFC-010 and repository orientation to the README.

Adopted "baseline" as the term for the invariant tier, retiring "floor" except as an explanatory metaphor; the collection namespace moved from `baseline` to `cur8s` to free the word.

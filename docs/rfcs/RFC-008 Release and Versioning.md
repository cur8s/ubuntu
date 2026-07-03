# RFC-008: Release and Versioning

Status: Accepted

## The Baseline Targets the Previous LTS

Ubuntu publishes a Long Term Support release every two years. The baseline always targets the previous LTS, not the current one: while Ubuntu 26.04 is the current LTS, the baseline targets 24.04, and it advances to 26.04 only after 28.04 ships.

An operating system release is one part of a much larger ecosystem. Kernels, package repositories, drivers, third-party software, and operational knowledge all evolve around it, and a new LTS can be stable in isolation while the ecosystem is still absorbing its changes. During the development of this repository, Linux 7.0 replaced PREEMPT_NONE with PREEMPT_LAZY as the default preemption model; that single kernel change cut PostgreSQL throughput roughly in half under some workloads, with no PostgreSQL change at all. Targeting the previous LTS gives the ecosystem two extra years to discover, document, and adapt to such cross-project interactions. The objective is to spend engineering effort operating software, not early-adopting operating system behavior.

## Version Scheme

Release versions are `MAJOR.MINOR.PATCH`, where major.minor mirror the targeted Ubuntu LTS — `24.4.x` for the 24.04 baseline — and the patch number counts collection releases. Semver forbids leading zeros, so `24.4` stands for 24.04; LTS releases are always April releases, so the year alone is unambiguous.

The baseline is forever backward-compatible within its LTS era. That policy, not version arithmetic, is the compatibility contract, and it is what makes a single release counter sufficient. When the baseline advances to the next LTS, a new series begins (`26.4.0`) and the previous series enters maintenance: fixes only, no new controls.

## Distribution

The baseline is packaged and distributed as an Ansible collection, `cur8s.ubuntu`, from its git repository only; it is not published to a galaxy registry. Consumers install it, and use-case collections depend on it, through git sources.

`main` is the production release. Every version bump in `galaxy.yml` is tagged `v<version>`. Environments that want reproducible pins or rollback targets pin tags; development tracks `main`.

## Scope

This RFC defines the supported-release policy, the version scheme, and the distribution model.

It does not define upgrade procedures between LTS eras or the release workflow (the operations manual).

## Revisions

Initial version.

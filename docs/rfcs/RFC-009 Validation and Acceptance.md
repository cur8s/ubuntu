# RFC-009: Validation and Acceptance

Status: Accepted

Baseline roles declare state; they do not verify outcomes (RFC-002: Baseline Doctrine). Verification lives in acceptance gates: opt-in playbooks that prove the baseline's promises hold on a real host.

Acceptance gates are never part of routine converge. A scheduled converge must stay safe to run against production at any time; a gate that reboots a host is not.

## Reboot Validation

The baseline's canonical acceptance gate reboots the host, waits for it to return, and then proves the contract survived: `ansible` and `sysadmin` can both SSH in and use sudo, the baseline services are active, and the journal still contains the previous boot — demonstrating the persistence pin end-to-end.

Reboot validation exists because the baseline's promises are boot-cycle promises. unattended-upgrades installs kernels that only a reboot activates; a host that converges cleanly but cannot survive a reboot is not conformant in any sense that matters.

## Architecture Coverage

The gates are architecture-blind, but coverage must not be: the same acceptance gates must pass on every supported architecture (RFC-010: Release and Versioning). The everyday proof machine is the local arm64 lab; the amd64 half is covered by the provider integration test, which runs the identical steel thread against a real cloud host — covering at once the second architecture and the provider realities (datasource, image, network) no local VM can simulate. That test is a release gate: no release ships until it passes on a real provider (the developer guide names the harness entry point).

## Gating Dangerous Changes

Lockout-sensitive operations require a passed acceptance gate first. Bootstrap retirement (RFC-004: Identity and Trust) is the canonical example: it removes the last provider-supplied access path, so it may be enabled only in environments whose hosts have passed reboot validation.

## Scope

This RFC defines where verification lives, the reboot-validation acceptance gate, and architecture coverage.

It does not define the doctrine that excludes verification from baseline roles (RFC-002: Baseline Doctrine) or the drift-detection semantics of converge (RFC-008: Convergence).

## Revisions

Initial version.

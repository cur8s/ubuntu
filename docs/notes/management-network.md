# Note: Management network — design idea

Status: Idea — a recorded design sketch, **not committed to be executed**.
The access layer it describes belongs to a future, separate collection
(`cur8s.tailscale`), not to this repository. A runnable technique demo
exists at `examples/tailscale/`.

Date: 2026-07-03 (carried over from the prototype RFC series)

In this idea, every managed host joins the Management Network. The
Management Network is the exclusive path for host administration: SSH,
operating system administration, and all other administrative services are
accessed only through it.

The sketch implements the Management Network with Tailscale, packaged as a
separate collection consumed alongside the baseline in the composition
model of RFC-001: The Host Baseline. Every managed host joins the tailnet
and becomes reachable to authorized administrators through that private
network.

The Management Network provides private encrypted connectivity,
authenticated device membership, identity-aware SSH with per-person
attribution, and centralized access control. It replaces the traditional
model of exposing administrative services directly on the public Internet.

The trust model defined by RFC-004: Identity and Trust establishes
bootstrap and break-glass access with long-lived SSH keys. Once a host has
joined the Management Network, its identity-aware SSH becomes the normal
mechanism for day-to-day administration. The `sysadmin` account remains
the recovery mechanism when the Management Network is unavailable.

Tailscale is an implementation choice rather than an architectural
requirement. Any implementation is acceptable provided it preserves these
properties.

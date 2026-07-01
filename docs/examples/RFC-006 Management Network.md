RFC-006: Management Network Example

Status: Example

This document is held as an example for a possible management network layer. It is not part of the active Host Baseline.

In this example, every managed host joins the Management Network.

The Management Network is the exclusive path for host administration. SSH, operating system administration, and all other administrative services are accessed only through the Management Network.

This example implements the Management Network using Tailscale. Every managed host joins the tailnet and becomes reachable to authorized administrators through that private network.

The Management Network provides private encrypted connectivity, authenticated device membership, identity-aware SSH, and centralized access control. It replaces the traditional model of exposing administrative services directly on the public Internet.

The SSH Trust Model defined by RFC-003 establishes the bootstrap trust relationship using a long-lived administrator SSH key. Once a host has joined the Management Network, Tailscale SSH becomes the normal mechanism for day-to-day administration. The administrator SSH key remains the recovery mechanism if access through the Management Network is unavailable.

Tailscale is an implementation choice rather than an architectural requirement. Future implementations are acceptable provided they preserve the architectural properties established by this RFC.

**Scope**

This example defines a possible management network for hosts built from the Host Baseline.

It does not define the SSH Trust Model, host provisioning, or the implementation details of Tailscale.

**Revisions**

Initial version.

Moved out of the active baseline RFC set while the Host Baseline is narrowed.

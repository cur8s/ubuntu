RFC-003: SSH Trust Model

Status: Accepted

Password-based SSH authentication is not part of the Host Baseline. Every managed host trusts a long-lived administrator SSH public key that establishes the initial trust relationship with the machine.

This administrator key is the bootstrap trust anchor. It exists to provision new hosts, recover inaccessible systems, and provide emergency administrative access.

Day-to-day administration should use stronger identity-aware mechanisms where available. For the Host Baseline, this is Tailscale SSH, which issues short-lived SSH credentials based on the authenticated user’s identity. The administrator SSH key remains a recovery mechanism rather than the primary means of administration.

The mechanism used to deliver the administrator public key is defined by RFC-004: Baseline Provisioning.

**Administrator Key Handling**

The administrator SSH private key is secret material. It must live outside this repository in an approved secrets manager.

Private key material must not be committed, embedded in source-controlled provisioning assets, or written into reusable templates.

The administrator SSH public key is distributable configuration. It may be rendered into cloud-init, NoCloud datasource media, or cloud provider metadata so that new hosts trust the administrator key during provisioning.

Operational documentation defines the concrete key storage, rendering, and rotation workflow.

**Scope**

This RFC defines the SSH trust model for the Host Baseline.

It does not define host provisioning, the operational steps for creating or rotating SSH keys, or higher-level remote administration mechanisms.

**Revisions**

Initial version.

Added administrator key handling expectations.

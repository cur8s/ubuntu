RFC-003: SSH Trust Model

Status: Accepted

Password-based SSH authentication is not part of the Host Baseline. Every managed host trusts a long-lived administrator SSH public key that establishes the initial trust relationship with the machine.

This administrator key is the bootstrap trust anchor. It exists to provision new hosts, recover inaccessible systems, and provide emergency administrative access.

Day-to-day administration should use stronger identity-aware mechanisms where available. For the Host Baseline, this is Tailscale SSH, which issues short-lived SSH credentials based on the authenticated user’s identity. The administrator SSH key remains a recovery mechanism rather than the primary means of administration.

The mechanism used to deliver the administrator public key is defined by RFC-004: Baseline Provisioning.

Scope

This RFC defines the SSH trust model for the Host Baseline.

It does not define host provisioning, SSH key lifecycle management, or higher-level remote administration mechanisms.

Revisions

Initial version.

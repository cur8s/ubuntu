RFC-003: SSH Trust Model

Status: Accepted

Password-based SSH authentication is not part of the Host Baseline. Every managed host trusts a long-lived administrator SSH public key that establishes the initial trust relationship with the machine.

This administrator key is the bootstrap trust anchor. It exists to provision new hosts, recover inaccessible systems, and provide emergency administrative access.

Day-to-day administration uses named non-root administrative users with key-based SSH access. The administrator SSH key remains the bootstrap and recovery mechanism rather than the primary means of routine administration.

Identity-aware management networks may be layered on top of the Host Baseline, but they are not part of the SSH trust model required by this RFC.

The mechanism used to deliver the administrator public key is defined by RFC-004: Baseline Provisioning.

**Approved SSH Public Key Type**

Baseline SSH public keys must use the `ssh-ed25519` OpenSSH public key type.

RSA, ECDSA, DSA, and other SSH public key types are not approved for baseline administrator, automation, or named administrative user access.

**Administrator Key Handling**

The administrator SSH private key is secret material. It must live outside this repository in an approved secrets manager.

Private key material must not be committed, embedded in source-controlled provisioning assets, or written into reusable templates.

The administrator SSH public key is distributable configuration. It may be rendered into cloud provider metadata, installation-time provisioning assets, or convergence inputs so that new hosts trust the administrator key.

Rendered administrator and administrative user public keys must use the approved SSH public key type.

Cloud provider metadata may establish the initial SSH path. Baseline convergence enforces the final administrator SSH public key state after the first SSH connection is available.

Operational documentation defines the concrete key storage, rendering, and rotation workflow.

**Scope**

This RFC defines the SSH trust model for the Host Baseline.

It does not define host provisioning, the operational steps for creating or rotating SSH keys, or higher-level remote administration mechanisms.

**Revisions**

Initial version.

Defined `ssh-ed25519` as the only approved baseline SSH public key type.

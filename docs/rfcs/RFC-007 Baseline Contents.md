RFC-007: Baseline Contents

Status: Draft

The Host Baseline is intentionally small.

Every component in the baseline must be useful on every managed host regardless of workload. Software whose primary purpose is to support a particular application, runtime, database, or deployment model belongs outside the baseline unless a later RFC expands the baseline with architectural justification.

This RFC defines the minimum contents of the Host Baseline.

**Baseline Contents**

A host conforms to the Host Baseline when it satisfies the following requirements:

* the supported Ubuntu LTS release
* unattended-upgrades for Ubuntu security and stable bug-fix maintenance
* the Ed25519 administrator SSH key for bootstrap and recovery access
* OpenSSH configured for Ed25519 key-based access with password authentication disabled

**Ubuntu Release and Package Maintenance**

The host runs the supported Ubuntu release defined by RFC-002: Baseline Ubuntu Release.

The host keeps Ubuntu packages current using Ubuntu's normal unattended package maintenance mechanisms. Automatic package maintenance may apply security updates and stable bug fixes for the supported Ubuntu release. It must not perform major Ubuntu release upgrades or intentionally move the host away from the baseline release defined by RFC-002.

**Administrator SSH Key**

The host satisfies the SSH Trust Model defined by RFC-003: SSH Trust Model.

The host trusts the administrator SSH public key defined by RFC-003. This key establishes the bootstrap trust relationship and remains available for recovery access.

Baseline SSH public keys use the `ssh-ed25519` OpenSSH public key type.

OpenSSH is configured for key-based access. Password-based SSH authentication is not part of the baseline.

Day-to-day administration uses named non-root administrative users with key-based SSH access. The administrator SSH key exists to preserve bootstrap and recovery access when a host has not yet completed initialization or when normal administrative access is unavailable.

**Scope**

This RFC defines the minimum contents of the Host Baseline.

It does not define how those requirements are implemented or how workload-specific software is layered onto a host.

**Revisions**

Initial version.

Clarified that baseline SSH public keys use the `ssh-ed25519` OpenSSH public key type.

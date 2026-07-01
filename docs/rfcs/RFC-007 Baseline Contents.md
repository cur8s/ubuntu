RFC-007: Baseline Contents

Status: Draft

The Host Baseline is intentionally small.

Every component in the baseline must be useful on every managed host regardless of workload. Software whose primary purpose is to support a particular application, runtime, database, or deployment model belongs outside the baseline unless a later RFC expands the baseline with architectural justification.

This RFC defines the minimum contents of the Host Baseline.

**Baseline Contents**

A host conforms to the Host Baseline when it satisfies the following requirements:

* the supported Ubuntu LTS release
* unattended-upgrades for Ubuntu security and stable bug-fix maintenance
* Tailscale for the Management Network
* Tailscale SSH for day-to-day administration
* Tailscale-managed automatic updates
* the administrator SSH key for bootstrap and recovery access
* OpenSSH configured for key-based access with password authentication disabled

**Ubuntu Release and Package Maintenance**

The host runs the supported Ubuntu release defined by RFC-002: Baseline Ubuntu Release.

The host keeps Ubuntu packages current using Ubuntu's normal unattended package maintenance mechanisms. Automatic package maintenance may apply security updates and stable bug fixes for the supported Ubuntu release. It must not perform major Ubuntu release upgrades or intentionally move the host away from the baseline release defined by RFC-002.

**Management Network**

The host joins the Management Network defined by RFC-006: Management Network.

The Host Baseline currently implements the Management Network with Tailscale. Convergence installs Tailscale, joins the host to the tailnet, enables Tailscale SSH, and enables Tailscale-managed automatic updates.

**Administrator SSH Key**

The host satisfies the SSH Trust Model defined by RFC-003: SSH Trust Model.

The host trusts the administrator SSH public key defined by RFC-003. This key establishes the bootstrap trust relationship and remains available for recovery access.

OpenSSH is configured for key-based access. Password-based SSH authentication is not part of the baseline.

Day-to-day administration uses the Management Network. The administrator SSH key exists to preserve access when the Management Network is unavailable or when a host has not yet completed convergence.

**Scope**

This RFC defines the minimum contents of the Host Baseline.

It does not define how those requirements are implemented or how workload-specific software is layered onto a host.

**Revisions**

Initial version.

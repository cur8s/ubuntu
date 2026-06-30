RFC-004: Baseline Provisioning

Status: Accepted

The Host Baseline supports two provisioning environments:

* Cloud virtual machines.
* Bare-metal installations.

Regardless of the provisioning environment, every host reaches the same state: a supported Ubuntu installation that satisfies the SSH Trust Model defined by RFC-003 and is reachable over SSH.

**Provisioning Responsibilities**

Provisioning has a single purpose: to produce a host that is ready for baseline convergence.

Its responsibilities are limited to:

* installing the supported Ubuntu release
* delivering an initial SSH trust path for the administrator SSH public key defined by RFC-003
* producing a host that is reachable over SSH

Provisioning does not apply the Host Baseline. Package installation, operating system configuration, security hardening, networking, firewall configuration, Tailscale, software updates, and every other aspect of the Host Baseline belong to baseline convergence.

Baseline convergence enforces the final administrator SSH public key state after the first SSH connection is available.

**Cloud Provisioning**

Cloud virtual machines use the cloud provider’s Ubuntu image and provider-native SSH key metadata.

Cloud provider SSH key metadata creates a key-based bootstrap path and avoids provider-specific password-based bootstrap behavior.

Cloud provisioning does not rely on cloud-init for the Host Baseline. After provider metadata establishes initial reachability, baseline convergence enforces the final administrator SSH public key state.

**Bare-Metal Provisioning**

Bare-metal hosts use Ubuntu Autoinstall.

The Host Baseline expects bare-metal provisioning to produce a supported Ubuntu installation that is reachable over SSH. Autoinstall should deliver the initial SSH trust path when possible.

If Autoinstall alone is not sufficient for a target environment, a NoCloud datasource or another installation-time mechanism may be added later.

**Scope**

This RFC defines the provisioning architecture for the Host Baseline.

It does not define baseline convergence, the exact contents of provider-specific provisioning assets, or the automation applied after provisioning.

**Revisions**

Initial version.

Clarified provider SSH metadata and convergence responsibilities.

Removed cloud-init from the cloud VM provisioning path.

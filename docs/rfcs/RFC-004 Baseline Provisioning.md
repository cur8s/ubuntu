RFC-004: Baseline Provisioning

Status: Accepted

The Host Baseline supports two provisioning environments:

* Cloud virtual machines.
* Bare-metal installations.

Regardless of the provisioning environment, every host reaches the same state: a supported Ubuntu installation that satisfies the SSH Trust Model defined by RFC-003 and is reachable over SSH.

Provisioning Responsibilities

Provisioning has a single purpose: to produce a host that is ready for baseline convergence.

Its responsibilities are limited to:

* installing the supported Ubuntu release
* delivering the administrator SSH public key defined by RFC-003
* producing a host that is reachable over SSH

Provisioning does not apply the Host Baseline. Package installation, operating system configuration, security hardening, networking, firewall configuration, Tailscale, software updates, and every other aspect of the Host Baseline belong to baseline convergence.

Cloud Provisioning

Cloud virtual machines use the cloud provider’s Ubuntu image together with cloud-init.

The Host Baseline uses cloud-init only to deliver the administrator SSH public key during instance creation.

Bare-Metal Provisioning

Bare-metal hosts use Ubuntu Autoinstall together with cloud-init.

The Host Baseline uses two installation media:

* Ubuntu Server installation media.
* A second NoCloud datasource containing the cloud-init configuration.

The NoCloud datasource delivers the same administrator SSH public key that a cloud provider would supply through cloud-init. As a result, cloud and bare-metal installations share the same provisioning architecture, differing only in how the cloud-init configuration is delivered.

Scope

This RFC defines the provisioning architecture for the Host Baseline.

It does not define baseline convergence, the contents of the cloud-init configuration, or the automation applied after provisioning.

Revisions

Initial version.

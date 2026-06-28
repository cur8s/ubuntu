# Ubuntu Production Bootstrap

This repository contains scripts and supporting tools for turning a fresh Ubuntu install into a production-ready host. It is intended for newly launched cloud VMs, bare-metal servers, and other clean Ubuntu environments that need a consistent baseline before running workloads.

The project will collect repeatable setup steps for system updates, security hardening, users and access, networking, observability, runtime dependencies, and operational checks.

## Philosophy

The goal of this project is to provide a stable, repeatable foundation for building and running applications. It is not a place to evaluate the latest operating system releases.

The baseline targets the previous Ubuntu LTS rather than the current one. This gives the broader ecosystem, including Kubernetes, k3s, container runtimes, security tools, drivers, and third-party packages, time to mature before it becomes part of the platform.

This project optimizes for boring infrastructure. Security updates and point releases should be applied promptly, but major operating system upgrades are intentionally deferred until the next LTS has been released and the ecosystem has stabilized. The intended result is fewer surprises, lower maintenance overhead, and more time spent developing applications instead of troubleshooting operating system compatibility issues.

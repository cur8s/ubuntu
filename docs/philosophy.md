# Philosophy

This project exists to create a stable, repeatable foundation for building and running applications on Ubuntu 24.04 LTS hosts.

It is not a test bed for arbitrary operating system releases. The default posture is to target Ubuntu 24.04 LTS, apply security updates promptly, and treat major operating system upgrades as explicit project work.

The operating principle is boring infrastructure:

- Prefer explicit scripts over hidden automation.
- Prefer idempotent steps that can be safely rerun.
- Prefer official package sources and scoped trust.
- Prefer verification checks next to every mutating module.
- Avoid provider-specific assumptions in shared bootstrap code.

The goal is to spend less time debugging host compatibility issues and more time running applications.

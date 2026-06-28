# Philosophy

This project exists to create a stable, repeatable foundation for building and running applications on Ubuntu hosts.

It is not a test bed for the newest operating system release. The default posture is to prefer the previous Ubuntu LTS, apply security updates promptly, and defer major operating system upgrades until the next LTS and the surrounding ecosystem have had time to stabilize.

The operating principle is boring infrastructure:

- Prefer explicit scripts over hidden automation.
- Prefer idempotent steps that can be safely rerun.
- Prefer official package sources and scoped trust.
- Prefer verification checks next to every mutating module.
- Avoid provider-specific assumptions in shared bootstrap code.

The goal is to spend less time debugging host compatibility issues and more time running applications.

# cur8s.ubuntu

The Ubuntu Host Baseline: the invariant state every managed Ubuntu host
gets, regardless of what runs on top.

This directory is the installable Ansible collection. Entry points:

- `cur8s.ubuntu.converge` — apply and re-assert the baseline.
- `cur8s.ubuntu.validate_reboot` — the reboot acceptance gate.
- `cur8s.ubuntu.update` — operator-invoked full package update (never reboots).

Everything else — architecture RFCs, the operations manual, consumption
examples, and the contributor test harness — lives at the repository root:
<https://github.com/cur8s/ubuntu>. The repository README carries the mental
model; `docs/operations/manual.md` is the how-to; the RFCs in `docs/rfcs/`
are the normative contract.

Install from git (no registry):

```sh
ansible-galaxy collection install 'git+https://github.com/cur8s/ubuntu.git#/collection/'
```

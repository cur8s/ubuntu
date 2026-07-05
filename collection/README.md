# cur8s.ubuntu

The Ubuntu Host Baseline: the invariant state every managed Ubuntu host
gets, regardless of what runs on top.

This directory is the installable Ansible collection. Entry points:

- `cur8s.ubuntu.converge` — enforce the baseline.
- `cur8s.ubuntu.patch` — operator-invoked patching: full package upgrade (never reboots).
- `cur8s.ubuntu.validate_reboot` — the reboot acceptance gate.
- `cur8s.ubuntu.report_access` — render the access surface: every door, every privilege holder. Read-only.
- `cur8s.ubuntu.lock_accounts` — close the doors of accounts named in `LOCK_ACCOUNTS`, after re-proving both baseline accounts.
- `cur8s.ubuntu.rotate_key` — re-key one baseline account via its sibling (`ROTATE_ACCOUNT`, `ROTATE_NEW_PUB_KEY`).
- `cur8s.ubuntu.adoptable` — read-only adoption verdict for an existing host (`ADOPT_USER`).
- `cur8s.ubuntu.adopt` — additively add the baseline accounts to an adoptable host.

Everything else — architecture RFCs, the guides, consumption
examples, and the contributor test harness — lives at the repository root:
<https://github.com/cur8s/ubuntu>. The repository README carries the mental
model; `docs/guides/` holds the user and developer guides; the RFCs in `docs/rfcs/`
are the normative contract.

Install from git (no registry):

```sh
ansible-galaxy collection install 'git+https://github.com/cur8s/ubuntu.git#/collection/'
```

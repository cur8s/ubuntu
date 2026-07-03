# Note: Adopting existing servers — design proposal

Status: Idea — a recorded design proposal, **not committed to be executed**.
Nothing described here exists in the collection. Revisit when adoption
becomes a priority; expect to re-validate the design against the code at
that time.

Date: 2026-07-03

## Problem

The baseline currently reaches hosts only at birth: cloud-init at first
boot (RFC-005) creates the baseline identities, and converge takes over
from there. Existing servers — e.g. bare-metal Ubuntu 24.04 hosts that
predate the baseline — have neither the `ansible` nor `sysadmin` accounts,
so converge cannot connect at all. Adoption is the missing bridge.

## Design summary

**Adoption is provisioning's third path, not a new kind of converge.**
RFC-005 defines provisioning's contract as "produce a host reachable over
SSH by the baseline identities." Cloud user-data does it at first boot;
autoinstall will do it for new bare metal; adoption achieves the same
outcome over SSH for hosts that already exist. Everything after that —
converge, update, validate_reboot, retirement — already exists and needs
no changes.

The pre-existing access account (the installer-created user on bare metal)
is not a new identity: it is RFC-004's "provider bootstrap user"
generalized to *the pre-baseline access path*, with the same lifecycle —
it makes the host reachable until the baseline accounts are proven, and
the existing retirement role (`BOOTSTRAP_USER=<olduser>`) retires it
afterward.

## Proposed pieces

**`cur8s.ubuntu.adoptable`** — a read-only assessment that connects as
`ADOPT_USER` (env-var input), writes nothing, and reports a verdict.

Hard failures (not adoptable until a human acts):

- wrong release (not the targeted Ubuntu LTS)
- no privilege path (`ADOPT_USER` cannot become root)
- `/etc/ssh/sshd_config` missing the `Include sshd_config.d` directive
  (converge's policy drop-in would be silently ignored)
- `/etc/sudoers` missing the `sudoers.d` include (the per-account sudo
  rules would be inert)
- squatted baseline accounts: `ansible` or `sysadmin` exists with
  authorized_keys the baseline didn't put there — refuse and report the
  foreign keys; never merge into or strip an unrecognized account. An
  account matching baseline shape reports as "already adopted".

Warnings (adoptable; know what happens next):

- password authentication currently enabled (converge will disable it —
  after adopt has created and validated key access)
- conflicting sshd drop-ins sorting before `10-ubuntu-baseline.conf`
- pending reboot already flagged by the OS
- current values converge will pin (unattended-upgrades reboot policy,
  journald storage) reported as the expected first-converge delta

**`cur8s.ubuntu.adopt`** — purely additive: release guard, the `users`
role (both accounts, ed25519 validation, locked passwords, passwordless
sudo), then the existing SSH+sudo validations for both accounts. Runs the
adoptability checks first (shared task file) and refuses on any hard
failure. It removes nothing, edits nothing that exists, and touches no
service. Auth for `ADOPT_USER` is whatever the host has — agent key, or
`--ask-pass`/`--ask-become-pass`; adoption is the one moment password
auth is tolerated, because it is what exists.

**The adoption runbook** composes from existing pieces, each stage gated
by the previous one's validation, the old access path surviving until the
new one is proven:

```
adoptable → adopt → converge → update → validate_reboot → retire (optional)
```

**Lab testing** — a `vm:create-adoptable` harness task creating a plain
droplet (no user-data, provider key only) faithfully simulates an existing
server; pre-sabotaging one (squat an `ansible` user, enable password auth)
proves the check catches what it claims.

## Deferred questions surfaced by this design

- **Key-drift reversion on baseline accounts**: `authorized_key` is not
  `exclusive`, so converge today does not remove foreign keys added to
  `ansible`/`sysadmin` after birth. Adoption-time squatting is handled by
  refusal (above); whether routine converge should enforce exclusive keys
  is a separate hardening decision.
- **Retirement of installer-created users is incomplete for bare metal**:
  the retirement role strips keys, the cloud-init sudoers file, and locks
  the password, but does not remove `sudo` group membership. Practically
  inert, but untidy; a "remove from privileged groups" step belongs in the
  retirement role when adopted-host retirement is actually exercised.

## Documentation impact when implemented

RFC-005 gains an Adoption section (third provisioning path, same
contract); RFC-004 generalizes the bootstrap identity wording; RFC-009
adds `cur8s.ubuntu.adoptable`, `cur8s.ubuntu.adopt`, and `ADOPT_USER`;
the manual gains the adoption runbook; the README mental model gains one
sentence.

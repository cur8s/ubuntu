# DigitalOcean integration

This folder runs the `cur8s.ubuntu` baseline on a real DigitalOcean
droplet, end to end: provision a host born conformant, converge it,
prove it survives a reboot, close the provider's bootstrap door, rotate
keys. It is three things at once:

- **This repository's integration test.** The root `test:integration:digital-ocean`
  task drives the tasks here against a real droplet and asserts the
  contract (second converge `changed=0`, reboot survived, access surface
  reduced to exactly the two baseline doors). It runs ad hoc and before
  every release (RFC-009: Validation and Acceptance).
- **An operational starting point.** The folder is self-contained — its
  own mise config, helpers, and state — so you can copy the directory
  into your own environment and have a working day-one operational
  surface. See "Copying this folder" below.
- **A disposable-VM workflow.** The same tasks serve "spin up a real VM
  for a few hours": create, converge, work, destroy. Nothing here
  assumes the droplet exists only to be tested.

Everything generated lands in the folder's own git-ignored `.generated/`.

## Prerequisites

`mise`, `doctl` (authenticated: `doctl auth init`), `jq`,
`ansible-playbook` (ansible-core ≥ 2.16), `ssh`, and `op` (1Password CLI —
the default custody wiring, swappable below). One-time per copy of this
folder: `mise trust`.

## Custody: where the keys live

The collection consumes public keys only; private keys live in a secrets
manager and its SSH agent, and are never written to disk (RFC-004:
Identity and Trust). This folder ships wired for **1Password** as a
worked example of that arrangement:

- The vault holds three SSH key items — `ubuntu-bootstrap`,
  `ubuntu-ansible`, `ubuntu-sysadmin` — each exposing a `public key`
  field. The `OP_*_KEY_REF` variables in `mise.toml` point at them.
- `key:prep` extracts the public halves with `op read` into
  `.generated/ssh` (they arrive `0600`, which ssh requires of identity
  files). Expect one agent approval per session.
- Every SSH and every playbook run signs through the 1Password SSH
  agent: the `-i <file>.pub` mechanic offers the public key, the agent
  supplies the signature. No private key ever exists outside the vault.
- Note for other tooling on the same workstation: 1Password installs a
  global `IdentityAgent` in `~/.ssh/config` that overrides
  `SSH_AUTH_SOCK`. That is exactly right for this folder — and worth
  knowing when something else on the machine must *not* use the vault.

**Swapping the vault**: edit `key/prep` (three lines — replace `op read`
with your secret manager's equivalent) and make sure your manager's SSH
agent serves the same keys, and update the `OP_*_KEY_REF` entries in
`mise.toml`. Nothing else in the folder knows 1Password
exists.

## The first host, start to finish

```sh
mise trust               # once per copy of this folder
mise run prep            # custody keys + DO bootstrap key + the collection
mise run up              # create -> first boot (upgrade + reboot) -> converge
mise run vm:status       # where am I? stages done, next command
mise run host:report-access      # observe every door before closing any
mise run host:validate-reboot    # acceptance gate (required before locking)
mise run host:lock-accounts      # close the provider's root door (the default)
mise run host:report-access      # confirm: exactly two doors remain
```

The droplet is born conformant: cloud-init applies the same accounts,
sudoers, and sshd policy the roles enforce, so the first converge changes
only the converge-only controls and the second reports `changed=0` —
that line is the conformance check, every time you run it.

`root` stays reachable through first boot as the provider's own
break-glass path (DigitalOcean injects the bootstrap key via its
metadata, outside the rendered user-data). Locking it is the deliberate,
separate act above — never a converge side effect (RFC-005: Accounts
and Access).

## Day two

- `mise run host:converge` — enforce the baseline any time;
  `changed=0` means conformant.
- `mise run host:patch` — apply every pending package upgrade; never
  reboots, reports if one becomes pending.
- `mise run ssh:ansible` / `ssh:sysadmin` — a shell, by account.

## Rotating a baseline key

Rotation replaces one account's key per invocation and enters through
the sibling account, so it never depends on the key being replaced
(RFC-004). The 1Password choreography around the host-side rotation:

1. **Generate the replacement in the vault** as a *second* item (e.g.
   `ubuntu-ansible-new`), so its private half never exists anywhere else.
2. Extract its public half and rotate:

   ```sh
   op read --force --out-file /tmp/ubuntu-ansible-new.pub \
     "op://devops/ubuntu-ansible-new/public key"
   ROTATE_ACCOUNT=ansible ROTATE_NEW_PUB_KEY=/tmp/ubuntu-ansible-new.pub \
     mise run host:rotate-key
   ```

   The playbook adds the new key, proves it over SSH with sudo, and only
   then reduces the account to exactly the new key — refusing if the
   account holds any key it does not expect.
3. **Retitle** the items (`ubuntu-ansible` → `ubuntu-ansible-retired-<date>`,
   `ubuntu-ansible-new` → `ubuntu-ansible`) and **archive** the retired
   one. Archiving evicts it from the SSH agent — the step that
   operationally kills the old credential — and the vault archive is the
   audit trail.
4. Re-extract (`mise run key:prep`) so `.generated/ssh` matches the vault
   again, then `mise run host:converge` and expect `changed=0`.

## Copying this folder

1. Copy the directory anywhere; run `mise trust` inside it.
2. Edit `mise.toml`: droplet name/size/region, your vault references.
3. `requirements.yml` installs the collection from git — pin the release
   tag. (Inside the cur8s/ubuntu repo, the root `test:integration:link-digital-ocean`
   task symlinks the working tree instead; a copy has no such link and
   always uses the pin.)
4. One folder describes one droplet. More hosts: copy per host, or grow
   your copy into a real inventory — at that point you are building your
   environment repository, which is exactly the intent.

The full consumer documentation is the user guide in the `cur8s/ubuntu`
repository (`docs/guides/user-guide.md`); the contract surface (FQCNs,
inputs, fixed account names) is RFC-011: Conventions Contract.

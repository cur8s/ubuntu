# User Guide

How to run the `cur8s.ubuntu` baseline on your own hosts: install the
collection, bring hosts in (born conformant or adopted), and operate them
for the rest of their lives. The RFCs in `docs/rfcs/` own the what and the
why; this guide owns the how, for consumers. If you are changing this
repository rather than using it, you want `docs/guides/developer-guide.md`.

## 1. What you need

- `ansible-core` ≥ 2.16, `ssh`, `git` on the machine you operate from.
- Two `ssh-ed25519` keypairs in your secrets manager — one for the
  `ansible` automation account, one for the `sysadmin` break-glass account
  (RFC-004: Identity and Trust). Their public halves as files on disk;
  the private halves stay in the secrets manager and its SSH agent,
  always. (For a fully worked 1Password arrangement — vault items,
  extraction, agent signing, rotation choreography — see
  `test/integration/digital-ocean/README.md`: a self-contained,
  copy-pastable operational folder built exactly this way.)
- Ubuntu 24.04 hosts, or a cloud account to create them. This series
  targets 24.04 only — every playbook refuses anything else (RFC-010:
  Release and Versioning).

## 2. Install the collection

Straight from git — there is no registry (RFC-010):

```sh
ansible-galaxy collection install 'git+https://github.com/cur8s/ubuntu.git#/collection/'
```

or in your environment repository's `requirements.yml` (the `examples/`
directory shows the full shape):

```yaml
collections:
  - name: https://github.com/cur8s/ubuntu.git#/collection/
    type: git
    version: main
```

Once release tags exist, pin one (`version: v24.4.0`) for reproducible
installs and rollback targets.

## 3. The contract you may hardcode

Everything below is stable and changes only by revision to RFC-011:
Conventions Contract.

**Accounts**: `ansible` (automation) and `sysadmin` (human break-glass) —
always present, locked passwords, key-only SSH, passwordless sudo.

**Playbooks** (all invoked by FQCN):

| Playbook | Does |
| --- | --- |
| `cur8s.ubuntu.converge` | assert the baseline; `changed=0` means conformant |
| `cur8s.ubuntu.update` | full package update; never reboots |
| `cur8s.ubuntu.validate_reboot` | acceptance gate: reboot, re-verify everything |
| `cur8s.ubuntu.report_access` | read-only access surface; always `changed=0` |
| `cur8s.ubuntu.lock_accounts` | close named accounts' login doors |
| `cur8s.ubuntu.adoptable` | read-only adoption verdict; nonzero exit on hard failures |
| `cur8s.ubuntu.adopt` | additively add the baseline accounts to an existing host |
| `cur8s.ubuntu.rotate_key` | re-key one baseline account through its sibling |

**Inputs** (environment variables): `ANSIBLE_PUB_KEY` and
`SYSADMIN_PUB_KEY` name your public key files; `LOCK_ACCOUNTS`,
`ADOPT_USER`, `ROTATE_ACCOUNT`, and `ROTATE_NEW_PUB_KEY` parameterize the
playbooks that take targets.

## 4. Hosts born conformant (cloud provisioning)

At first boot, cloud-init creates the accounts, applies the SSH policy,
dist-upgrades, and reboots — the host arrives already conformant
(RFC-006: Provisioning). Render the user-data from the same sources the
roles own:

```sh
export ANSIBLE_PUB_KEY=~/keys/ubuntu-ansible.pub
export SYSADMIN_PUB_KEY=~/keys/ubuntu-sysadmin.pub
export CLOUD_INIT_FILE=./ubuntu-baseline.yaml
sh <collection>/scripts/render-cloud-init.sh
```

Pass the rendered file as the instance's user-data, and register a
bootstrap SSH key with the provider (its `root`/`ubuntu` door stays open
as a debug path until you lock it — §6). First boot takes a few minutes
because of the upgrade-and-reboot cycle; then:

```sh
ansible-playbook -i <host>, cur8s.ubuntu.converge
```

On that first converge only the converge-only pins report `changed`
(unattended-upgrades and journald); accounts and SSH policy are already
no-ops because cloud-init applied them from the same sources.

The executable version of this whole section, DigitalOcean edition, is
`test/integration/digital-ocean/` in the collection repository — every
step above as a runnable task, ready to copy into your environment.

## 5. Hosts that already exist (adoption)

Anything not born via cloud provisioning — bare metal however installed,
inherited servers — enters through adoption (RFC-007), connected as
whatever pre-baseline account the host has:

```sh
ADOPT_USER=olduser ansible-playbook -i <host>, cur8s.ubuntu.adoptable
ADOPT_USER=olduser ansible-playbook -i <host>, cur8s.ubuntu.adopt
```

Authentication is whatever exists — an agent key, or `--ask-pass` and
`--ask-become-pass`; adoption is the one moment password auth is
tolerated. The assessment prints the host's access surface, the
baseline-account states, warnings naming exactly what the first converge
will change, and hard failures (wrong release, no root path, ignored
drop-in directories, squatted baseline accounts). It exits nonzero on
hard failures, so it can gate scripts; `adopt` refuses on the same
grounds, adds the two accounts, and proves them over SSH with sudo.

The full on-ramp, each stage gated by the one before, the old access
path surviving until the new one is proven:

```
adoptable → adopt → converge → validate_reboot → lock the old doors (§6)
```

## 6. Runbooks

**Converge** — routine, safe to schedule, forever:

```sh
ansible-playbook -i inventory cur8s.ubuntu.converge
```

On a healthy steady-state host every run reports `changed=0`; a non-zero
count is a drift report — read it, don't rerun past it. Converge asserts
and never removes access (RFC-008: Convergence): no door closes as a
side effect, so a scheduled converge can run blind. For detection
without enforcement, add `--check --diff`. If your network drops SSH
bursts, set `SSH_SPACING_SECONDS` to pause before SSH-heavy runs.

**Update** — deliberate full patching (the automatic baseline covers
security updates only):

```sh
ansible-playbook -i inventory cur8s.ubuntu.update
```

It never reboots; if a reboot becomes pending it says so and defers to
the gate below.

**Validate-reboot** — the acceptance gate (RFC-009): reboots the host,
re-verifies both accounts' SSH + sudo, baseline services, and journal
history across the boot. Opt-in only; run it before anything
lockout-sensitive.

**Report access** — who can get in?

```sh
ansible-playbook -i inventory cur8s.ubuntu.report_access
```

Read-only, always `changed=0`: every door (keys, unlocked passwords),
every privilege holder, foreign keys on the baseline accounts. Doorless
service accounts never appear — the report is filtered by doors, not
accounts (RFC-005: Accounts and Access).

**Lock accounts** — close doors deliberately, never automatically:

```sh
LOCK_ACCOUNTS=root ansible-playbook -i inventory cur8s.ubuntu.lock_accounts
```

Re-proves both baseline accounts first, refuses baseline accounts and
the connection user as targets, then strips keys, locks the password,
and removes privileged-group and provisioning-time sudo grants. Locked
accounts still run their processes and own their files; recovery is a
console. Deleting accounts you no longer want is yours to do by hand.

**Rotate a key** — one account per invocation, entered through the
sibling so the operation never depends on the key it replaces (RFC-004):

1. Generate the replacement in your secrets manager (ed25519; the
   private half never touches disk). Keep the old key available to your
   agent until the fleet is done.
2. With your environment still pointing at the *current* public keys:

   ```sh
   ROTATE_ACCOUNT=ansible ROTATE_NEW_PUB_KEY=~/keys/new.pub \
     ansible-playbook -i inventory cur8s.ubuntu.rotate_key
   ```

   It adds the new key, proves it, then reduces the account to exactly
   the new key — refusing if the account holds any key it does not
   expect. Safe to re-run; a finished host reports `changed=0`.
3. Retire the old key in your secrets manager, point `ANSIBLE_PUB_KEY`
   (or `SYSADMIN_PUB_KEY`) at the new public key, and converge:
   `changed=0` everywhere plus a clean `report_access` confirms
   completion.

   (The 1Password version of this choreography — second vault item,
   retitle, archive-evicts-from-agent — is worked step by step in
   `test/integration/digital-ocean/README.md`.)

## 7. Composing on top

Purpose layers (a k3s node, a database host) import
`cur8s.ubuntu.converge` first, then apply their own state — every tier
re-asserts the baseline (RFC-001). The `examples/` directory holds eight
runnable demonstrations of the pattern, shaped like a consumer
environment repository: inventory, `requirements.yml`, a `site.yml` that
composes the baseline with a purpose.

## 8. Going deeper

The RFCs read in order — RFC-000 through RFC-011 — and are the normative
contract behind everything above. Start with RFC-001: The Host Baseline
for the model, RFC-005: Accounts and Access for the doors-and-verbs
philosophy the runbooks implement, and RFC-011 for the full contract
surface.

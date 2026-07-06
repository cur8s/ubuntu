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
  extraction, agent signing, rotation choreography — see the README of
  the DigitalOcean harness developed in this repository's history:
  `test/integration/digital-ocean/` at commit `b0ba5ff`, a
  self-contained, copy-pastable operational folder built exactly this
  way.)
- Ubuntu 24.04 hosts, or a cloud account to create them. This series
  targets 24.04 only — every playbook that changes a host refuses any
  other release (RFC-010: Release and Versioning); `report_access` alone
  runs anywhere, because observing a surface is never the wrong move.

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
| `cur8s.ubuntu.converge` | enforce the baseline; `changed=0` means conformant |
| `cur8s.ubuntu.patch` | full package upgrade; never reboots |
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

The same rendered user-data serves any platform that speaks cloud-init —
a KubeVirt VM consumes it as a NoCloud volume unchanged. Platforms with
no cloud-init at all are not provisioned; they are adopted (§5).

A fully worked DigitalOcean edition of this section — every step above
as a runnable task, ready to copy into your environment — lives in the
repository history at `test/integration/digital-ocean/` (commit
`b0ba5ff`); copy it from there as a starting point.

## 5. Hosts that already exist (adoption)

Anything not born via cloud provisioning — bare metal however installed,
inherited servers — enters through adoption (RFC-007). For physical
machines this is the designed path, not a fallback: install Ubuntu
Server by hand, then adopt. The baseline deliberately ships no
bare-metal install automation — an install rare enough to do by hand
does not earn permanent surface. Connect as whatever pre-baseline
account the host has:

```sh
# ANSIBLE_PUB_KEY and SYSADMIN_PUB_KEY must be exported, as in every
# runbook (§1): adoption validates them before touching the host.
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
count is a drift report — read it, don't rerun past it. Converge enforces
and never removes access (RFC-008: Convergence): no door closes as a
side effect, so a scheduled converge can run blind. For detection
without enforcement, add `--check --diff`. If your network's IPS drops
SSH bursts, space out SSH-heavy runs (the collection needs nothing
special; pace them however your scheduler allows).

**Keep it conformant** — nothing runs on your hosts and nothing runs by
itself: the baseline holds because converge runs, and the recap is the
health check. Ad hoc is the default posture:

```sh
ansible-playbook --check --diff -i inventory cur8s.ubuntu.converge  # drift alarm: names any drift, changes nothing
ansible-playbook -i inventory cur8s.ubuntu.converge                 # enforce
```

The alarm has two volumes: ordinary drift shows as `changed!=0` with the
diff naming it; drifted *SSH policy* fails the check run outright,
because the effective-configuration assert verifies reality even in
check mode. Either way the exit tells the story and nothing was
touched.

If you want the loop continuous, schedule converge in your environment
repository's CI and alert on `changed!=0` — the automation key living in
CI is exactly the exposure the two-account split was designed for
(RFC-004: a CI compromise never costs break-glass access). A minimal
GitHub Actions shape (a sketch — your environment repository owns the
real one, including known_hosts and key handling):

```yaml
on:
  schedule:
    - cron: "17 6 * * *"
jobs:
  converge:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ansible-galaxy collection install -r requirements.yml
      - name: Converge; any change is the drift alarm
        env:
          ANSIBLE_PUB_KEY: keys/ubuntu-ansible.pub
          SYSADMIN_PUB_KEY: keys/ubuntu-sysadmin.pub
        run: |
          eval "$(ssh-agent)" && ssh-add - <<< "${{ secrets.ANSIBLE_PRIVATE_KEY }}"
          ansible-playbook -i inventory cur8s.ubuntu.converge | tee converge.log
          ! grep -qE 'changed=[1-9]' converge.log
```

Deliberately unsupported: `ansible-pull`, where every host cron-pulls
the repository and converges itself. That is an agent in a trench coat
— git, credentials, and a schedule on every managed host — and it
inverts the agentless trust model this collection is built on.

**Patch** — deliberate full patching (the automatic baseline covers
security updates only):

```sh
ansible-playbook -i inventory cur8s.ubuntu.patch
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
every privilege holder, unexpected keys on the baseline accounts. Doorless
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
   retitle, archive-evicts-from-agent — is worked step by step in the
   DigitalOcean harness README: repository history,
   `test/integration/digital-ocean/` at `b0ba5ff`.)

## 7. Composing on top

Purpose layers (a k3s node, a database host) import
`cur8s.ubuntu.converge` first, then apply their own state — every tier
enforces the baseline (RFC-001). The `examples/` directory holds three
runnable demonstrations of the pattern — docker (vendor apt repo), zot
(release binary run as a service you define), tailscale (secret-gated
join of an access network) — each a `site.yml` that composes the
baseline with a purpose, ready to drop into an environment repository
beside your inventory and `requirements.yml`.

Where should a thing you build live? Apply the version-pressure test:
if changing your mind about it would force a release of the artifact it
lives in, it belongs elsewhere. A layer with a real contract of its own
(a Kubernetes distribution, a database platform) earns its own
repository, versioned and proven like this one, consuming the baseline
from a pinned `requirements.yml` the way any consumer harness does.
Site policy — the
access network all *your* hosts join, security scanners, fleet
configuration — lives in your environment repository, applied to
inventory groups: "on all my hosts" means your inventory's `all` group,
not a wider collection. The baseline itself is a floor, not a practice;
it releases when Ubuntu-level facts change, never because a layer above
it changed its mind — and composition reaches only upward, so the
baseline never tests or promises any particular layer.

**A local lab for your layer.** A consumer repository that wants the
same free, unattended QEMU loop this repository uses needs exactly
three pieces, none copied by hand:

1. Vendor `qemu-vm.sh` from its upstream,
   [cur8s/qemu](https://github.com/cur8s/qemu) — a custody-neutral,
   single-file VM harness; its header carries the pinned refresh
   command.
2. Install this collection; the lab tooling ships inside it:
   `scripts/render-cloud-init.sh` renders baseline user-data from your
   public keys, and `scripts/activate-test-credentials.sh` is the custody
   shim — source it from bash and call `activate_test_credentials` to get
   throwaway keypairs, the promptless signing agent the collection's
   pub-as-identity connections require, and the exported env
   (including `QVM_SSH_IDENTITY_AGENT`, which wires the vendored
   `qemu-vm.sh ssh` to the same agent). Because the shim ships with
   the collection, its mechanics always match the collection version
   you installed.
3. Wire your task runner's environment: `QVM_DIR`, `QVM_CACHE_DIR`,
   `QEMU_KEYS_DIR`, and friends — see this repository's `mise.toml`
   for the working example.

## 8. Installing deb packages (reference)

Every purpose layer starts by getting software onto the host. These are
the patterns, from basic to full, ready to lift into a layer playbook.
Whatever the pattern, end with validation: run the tool's version
command and, for services, `systemctl is-active`, as in-play proof the
install worked.

**Stock Ubuntu archive.** Nothing to trust, nothing to add:

```yaml
- name: Install chrony
  ansible.builtin.apt:
    name: chrony
    state: present
```

**Vendor apt repository, modern form (deb822).** One `.sources` file
carries the repo and its trust anchor; `Signed-By` points at the
vendor's key fetched to a root-owned path (an ASCII `.asc` works
directly — no dearmoring). Detect the architecture, never assume it:

```yaml
- name: Read dpkg architecture
  ansible.builtin.command: dpkg --print-architecture
  register: dpkg_architecture
  changed_when: false

- name: Trust packages signed by the vendor
  ansible.builtin.get_url:
    url: https://example.com/vendor.asc
    dest: /etc/apt/keyrings/vendor.asc
    owner: root
    group: root
    mode: "0644"

- name: Add the vendor apt repository
  ansible.builtin.copy:
    dest: /etc/apt/sources.list.d/vendor.sources
    owner: root
    group: root
    mode: "0644"
    content: |
      Types: deb
      URIs: https://example.com/apt
      Suites: noble
      Components: stable
      Architectures: {{ dpkg_architecture.stdout }}
      Signed-By: /etc/apt/keyrings/vendor.asc

- name: Install the vendor package
  ansible.builtin.apt:
    name: vendor-package
    state: present
    update_cache: true
```

The `examples/docker/` playbook is this pattern live.

**Vendor publishes ready-made keyring and list files.** Some vendors
(Tailscale) host both a binary keyring and a matching `.list`; fetch
the pair verbatim instead of authoring anything — see
`examples/tailscale/`.

**Legacy: ASCII key that must be dearmored.** Older vendor docs
(osquery, CISOfy/lynis) publish an ASCII-armored key referenced from a
one-line `.list`, which needs converting once. Keep it idempotent by
keying the conversion on the download's change plus the keyring's
existence:

```yaml
- name: Download vendor signing key
  ansible.builtin.get_url:
    url: https://example.com/pubkey.gpg
    dest: /tmp/vendor-key.pub
  register: vendor_signing_key

- name: Check vendor keyring
  ansible.builtin.stat:
    path: /usr/share/keyrings/vendor-archive-keyring.gpg
  register: vendor_keyring

- name: Trust packages signed by the vendor
  ansible.builtin.command:
    cmd: >-
      gpg --dearmor --yes --output
      /usr/share/keyrings/vendor-archive-keyring.gpg
      /tmp/vendor-key.pub
  changed_when: vendor_signing_key.changed or not vendor_keyring.stat.exists

- name: Add the vendor apt repository
  ansible.builtin.copy:
    dest: /etc/apt/sources.list.d/vendor.list
    content: |
      deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/vendor-archive-keyring.gpg] https://example.com/deb stable main
```

Prefer the deb822 form whenever the vendor's key can be fetched
directly; this dance exists only for repos documented the old way.

**Pinning a major version.** Vendors that ship parallel major versions
(PGDG, others) encode the version in the package name — install
`postgresql-18`, not `postgresql`, and upgrades within the major flow
through `cur8s.ubuntu.patch` while the major stays put.

**A package whose daemon you do not want.** Installing for the CLI
only (osquery's `osqueryi`): install the package, then keep its service
down — `systemd_service` with `enabled: false, state: stopped` — and
assert it stays down via `service_facts`.

## 9. Going deeper

The RFCs read in order — RFC-000 through RFC-011 — and are the normative
contract behind everything above. Start with RFC-001: The Host Baseline
for the model, RFC-005: Accounts and Access for the doors-and-verbs
philosophy the runbooks implement, and RFC-011 for the full contract
surface.

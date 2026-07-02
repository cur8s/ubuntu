# RFC-001: Baseline Ubuntu — Goals & Architecture

Status: Draft

This RFC records the goals of the `baseline.ubuntu` project and the architecture aligned on to serve them. It is the "why" and the "shape"; role- and task-level design follows from it. It builds on RFC-000 (SSH Key Strategy).

## 1. Purpose

Provide a **known, hardened, reproducible starting state for Ubuntu hosts** — a stemcell, in the BOSH sense. Every VM begins from the same baseline, on any provider, with conventions higher-level automation can rely on. This repository is the baseline plus the tooling to keep hosts converged to it; other repositories build specialized hosts (k3s, Postgres, …) on top.

## 2. Goals

1. **Known baseline, any provider** — stand up an Ubuntu host on any cloud provider or bare metal and land in an identical, hardened, production-fit state.
2. **Repeatable remote management** — manage hosts with **agentless Ansible**, reusable as a collection.
3. **Drift detection and convergence** — verify the baseline is intact, report divergence, and re-assert it.
4. **Production-grade** — if a host came from this repo, it is fit for production; the repo is the reproducible path, no snowflake steps.
5. **Composability** — specialized automation in other repos builds on the baseline as a stable foundation.
6. **Security-critical, secure by default** — a hardened floor that is enforced, with any relaxation made deliberately and visibly.

## 3. Scope, support, and non-goals

- **This repo is `baseline.ubuntu`** — the generic collection — **plus a contributor test harness** (the `mise`/`doctl`/1Password workflow used to exercise it). It is *not* a production environment repo.
- **Ubuntu support: N-1 LTS of Ubuntu Server only** — the baseline always targets the *previous* LTS, not the current one (e.g., while 26.04 is current, the baseline targets 24.04, advancing to 26.04 only once 28.04 ships). Versioning is **semver, tiered to the Ubuntu release**. Rationale: an OS release is one part of a larger ecosystem (kernel, package repos, drivers, third-party software, operational practice), and a new LTS can be stable in isolation while the ecosystem is still absorbing its changes. Concrete case seen during development: Linux 7.0's switch from `PREEMPT_NONE` to `PREEMPT_LAZY` cut PostgreSQL throughput ~50% under some workloads with no PostgreSQL change. Targeting N-1 gives the ecosystem ~two extra years to discover, document, and adapt to such cross-project interactions, so engineering effort goes into building and operating rather than early-adopting OS behavior.
- **Non-goals (they belong to layers, environment repos, or the provider):** golden-image building (Packer); Terraform/IaC provisioning; per-host agents or self-healing daemons; network perimeter/firewall policy; application/workload configuration; specific human-user definitions; secrets storage and scheduling.

## 4. Provisioning model

- **No golden image.** Start from the **provider's latest official Ubuntu LTS** image and customize; do not bake or maintain a private snapshot.
- **Provider-native CLIs, no Terraform.** Create/destroy VMs with `doctl`/`aws`/`gcloud`/`az`.
- **Two stages:** provider **cloud-init user-data at first boot** establishes access and applies the file-shaped policy; **Ansible converge** owns and maintains the full baseline (see §5).
- **Bare-metal portability.** The same host-shaping config is portable to bare metal via `autoinstall` (the cloud-config nested under `autoinstall.user-data`), seeded through the NoCloud datasource.

## 5. cloud-init / converge division of labor

**The Ansible roles are the single source of truth for the full baseline.** cloud-init and the roles apply the file-shaped pieces from the *same sources*, so those pieces cannot diverge.

**cloud-init, at first boot:**
- creates **both access accounts** — `ansible` (automation door) and `sysadmin` (human break-glass) — with their authorized keys and sudo, so the host is reachable by its intended identities immediately;
- performs an **`apt` full-upgrade** to pull the latest packages *and kernel* (first boot is the ideal moment — the box is empty), then **reboots** to activate the new kernel;
- lays down the **sshd hardening drop-in** from the role-owned source file.

**converge (the roles) is the single source of truth:**
- **re-asserts** the accounts and sshd policy (correcting drift — a deleted key, a changed sudoer), and
- applies the **behavioral/stateful controls it alone owns**: unattended-upgrades, time sync, audit, and bootstrap retirement (§8).

**Lifecycle:** *boot → cloud-init (both accounts + full-upgrade + reboot + sshd file) → first converge (adds the behavioral controls) → every subsequent converge is a no-op* (the GitOps steady state).

**First converge is a no-op for users and SSH hardening**, because cloud-init already applied them from the same sources — only the behavioral controls do new work on the first converge. What "the same" requires depends on how Ansible detects change, which is **per-module**:

- **Accounts, keys, and group membership** are managed by **state-based modules** (`user`, `authorized_key`, `group`) that compare *system state*, not bytes — they report `changed` only when a specified attribute differs. So cloud-init and the roles only need the same **end state** (the user exists with the same shell and locked password, the same key present, the same groups). There is no need to make cloud-init's user block byte-mirror the role.
- **File-shaped controls are checksum-compared** (`copy`/`template`), so they need matching **content**. Exactly two controls are file-shaped: the **sshd drop-in**, and the **NOPASSWD sudoers rule** (NOPASSWD *requires* a sudoers file — group membership alone grants only password sudo). These use the shared-source-file discipline: a single file (e.g. `/etc/sudoers.d/baseline`) written by both cloud-init and the roles — *not* cloud-init's `sudo:` shortcut, which writes a different combined `/etc/sudoers.d/90-cloud-init-users` that would show as drift.

So the **"one source, two moments"** shared-file discipline applies to exactly **two files** (the sshd drop-in and the sudoers file); accounts and keys just need matching **state**. Behavioral controls stay converge-only.

**First-boot patching complements the floor, it doesn't replace it.** First-boot upgrade catches the stale provider image up to current; **unattended-upgrades** (a floor item) keeps it patched over time. Converge *ensures* unattended-upgrades is configured but **does not** blanket-`apt upgrade` on every run. Known hazard to handle: the first-boot package step can race the `apt-daily`/`unattended-upgrades` timers for the dpkg lock.

## 6. Management & drift model

- **Agentless Ansible, push from a control node.** No per-host agent, no self-healing daemon.
- **Reconciliation is on demand:** run converge **ad-hoc from a laptop** (private keys from the 1Password SSH agent) and/or **on a schedule from a consumer's environment repo** (e.g., a GitHub Action). Same playbook either way.
- **GitOps semantics at converge time.** Desired state is declared in git; converge re-asserts it. Drift — an out-of-band change by a person *or an AI agent* — is reverted on the next converge. **Only declared, in-git changes stick.** This makes every change auditable: the git commit is the *who/why*, the converge run is the *what/when*.
- **Detect vs. enforce = one playbook, one flag.** Detect = `converge --check --diff` (reports what differs, changes nothing); enforce = `converge`. Roles are authored **check-mode-clean** so the drift report is trustworthy.

## 7. The security floor

A **two-tier** model:

- **The immovable floor** — a fixed set of invariants, always enforced, never turned off, re-asserted on every converge on every host (self-healing against drift).
- **Layers** — everything optional or overridable. Being disable-able is what makes something a **layer**, not baseline. Layers **add** posture; the baseline is minimal.

**Floor inclusion test.** A control belongs in the floor only if all three hold: (1) it is a security/correctness invariant for *any* production Ubuntu regardless of role; (2) there is no legitimate reason it would ever need to be off; (3) enforcing it cannot break arbitrary future workloads or lock you out.

**Floor contents (OS/access hygiene):**
- SSH hardening — key-only auth, no password auth, no root password login (the shared sshd drop-in).
- No blank/default passwords; locked default accounts.
- The **`ansible` automation door** and the **`sysadmin` break-glass account** (see §8).
- Automatic security updates (unattended-upgrades).
- Time synchronization.
- Baseline audit/log capture.

**Explicitly *not* in the floor, and why:**
- **Kernel/sysctl tuning** — layered. Some knobs (e.g., `ip_forward`, namespaces, BPF, ptrace) must be settable by layers like k3s; blanket immovable hardening would break them.
- **Host firewall / ufw** — layered. Firewall policy is role-specific and a wrong rule can lock you out.
- **fail2ban** — not baseline. Key-only SSH makes brute-force moot, and a self-banning daemon is a self-lockout risk that cuts against "don't lock ourselves out."
- **Network perimeter** — a use-case concern (typically the cloud provider's firewall/security group at provision time, with host firewalling as an opt-in layer).

## 8. Account & access model

The baseline uses three roles; two are baseline-provisioned named accounts, one is the provider's bootstrap user.

- **`ansible`** — automation identity. Its key is used by converge and therefore lives in the environment repo's CI (scheduled runs) *and* the operator's 1Password (ad-hoc). Non-interactive, constant use, higher exposure.
- **`sysadmin`** — human break-glass admin. Its key lives in 1Password only, is human-present, and is used when the identity/access layer is unavailable or not yet joined. Rare use, lower exposure. **The durable break-glass.**
- **provider bootstrap user** — provider-specific first-login account (`root` on DigitalOcean, `ubuntu` on AWS/GCP, the `--admin-username` on Azure). The baseline **never assumes `root`** and **does not depend on direct root SSH**.

Both `ansible` and `sysadmin` are **created by cloud-init at first boot** and **re-asserted by the roles** as source of truth (see §5).

**Why two named accounts, not one.** Per-person attribution is the access layer's job, so these accounts are role-scoped, not per-person, and carry the same sudo policy. The separation exists for **credential custody and blast radius**: the automation key sits in CI (a higher-exposure trust zone) while the break-glass key never leaves 1Password, so the CI automation key can be rotated or revoked **independently** — a CI compromise never costs you break-glass, and vice versa. This is the "automation credential on a runner" condition that makes the separation real rather than cosmetic.

**Why fixed names.** `ansible` and `sysadmin` are **hardcoded, non-overridable** — a stable contract of the bottom layer, so Tailscale ACLs, sudo-log parsing, break-glass runbooks, and use-case collections can hardcode them with zero config. They are **role** names, not specific humans, so this does not violate genericity (the *keys* installed into them remain consumer inputs). The names are **self-documenting** for humans and AI coding agents, reducing the chance of conflating the two roles. `sysadmin` also avoids concrete traps that disqualify `admin`: the Ubuntu `admin` *group* (a `useradd` collision) and Azure's reserved-name list.

**Normalization + bootstrap retirement.** The baseline normalizes: it creates `ansible` + `sysadmin` at first boot, so *post-boot every host looks identical regardless of provider*. Once replacement access is **validated**, the baseline **retires the provider bootstrap account's access** at converge time — strips its `authorized_keys` and cloud-init `NOPASSWD` sudo and **locks** it (it is *not* deleted, which is provider-specific and can be undone by the provider's own tooling). On DigitalOcean this leaves root with no key (no root SSH); the account remains but inert. The handoff is safe with no break-glass gap: the bootstrap user stays usable until converge has created *and validated* `sysadmin`, and is retired only then; if converge fails, bootstrap is not retired.

**Secrets.** The baseline handles **public keys only**; private keys live solely in the 1Password SSH agent (because coding agents run on the operator's laptop). A small set of **well-known, reused named keys** is used, not per-VM keys. **Standing credentials** appear only in a consumer's environment repo (a scheduled runner needs the automation key); the generic collection holds none.

## 9. Identity & audit

- **Baseline attribution is role-level** (automation vs. human) plus *what/when/why* via git + converge logs.
- **Per-person "who" is provided by an access layer, not the baseline** — Tailscale supplies IdP-backed per-person identity, `check`-mode re-auth, and session recording.
- The baseline's job re: any access layer is only to **not fight it**: keep OpenSSH for bootstrap/break-glass, keep a per-person-capable model, and keep perimeter layered.

## 10. Composition — three tiers

1. **`baseline.ubuntu`** (this repo) — generic collection: the floor + parameterized mechanisms. No secrets, no inventory, no schedule.
2. **Use-case collections** (e.g., `baseline.k3s`) — depend on `baseline.ubuntu`; their converge **calls the baseline converge first** (re-asserting the floor), then applies their role.
3. **Environment repos** (a consumer's deployment) — pull in the use-case collection(s), hold the **inventory, host specifics, and keys**, and run converge (ad-hoc and/or scheduled).

Because every tier re-asserts `baseline.ubuntu`, the floor is guaranteed on **every** host, on every converge.

- **Tailscale is a separate `baseline.tailscale` collection**, opt-in by inclusion — never baked into the baseline (which must stay access-agnostic and work without a tailnet). Its authkey (a secret) lives in the environment repo. It doubles as the **canonical dogfood test** that a consumer collection correctly depends on and re-asserts `baseline.ubuntu`.
- **Network-security profiles** (e.g., "internet-facing" → ufw + hardening) are **layers**, starting per-use-case, with a possible shared `baseline.internet-facing` collection later.

## 11. Validation

- **Drift:** `converge --check --diff` reports divergence without changing anything.
- **Reboot validation** is a **separate, opt-in acceptance test — never part of routine converge** (rebooting on every scheduled converge is unacceptable for prod). It reboots, waits for the host to return, re-verifies that **`ansible` and `sysadmin` can SSH and `sudo`**, and confirms **floor services are healthy** post-boot. It lives in the collection as an acceptance gate and is wired into the contributor test harness.

## 12. Operational constraint — scanning IPS

**SSH-heavy operations (reboot validation, first converge) should originate from a control node *not* behind a scanning IPS** — CI or the tailnet — **not** bursted from a workstation behind a home-gateway IPS. The reboot-wait poll in particular generates a burst of port-22 connection attempts that reads as a port scan. (See `docs/notes/ucg-fibre-ips-ssh-blocking.md` — this incident shaped the whole design.)

## 13. Conventions (the stable contract)

Consumers may rely on: the account names **`ansible`** and **`sysadmin`**; those accounts always being present with passwordless sudo; and the sshd baseline drop-in. (To be extended as roles are built — paths, exposed Ansible facts/variables.)

## 14. Open items

- Enumerate the full **conventions contract** (paths, facts) as roles are implemented.

## 15. References

- `docs/rfcs/RFC-000 SSH Key Strategy.md`
- `docs/notes/ucg-fibre-ips-ssh-blocking.md`

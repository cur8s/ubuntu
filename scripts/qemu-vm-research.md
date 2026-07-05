# qemu-vm.sh — packaging research and decision record

Date: 2026-07-05. Two parallel research passes (existing-tool survey;
distribution mechanics), each adversarially verified against primary
sources by its own verification agents, plus the in-house analysis that
framed them. This document is the durable record; the decisions it
produced are implemented in github.com/cur8s/qemu.

## The decision, in short

- The niche is real: no well-known tool boots VMs from **plain
  cloud-init user-data** (the same `#cloud-config` that provisions a
  real cloud host) on **both macOS/hvf and Linux/KVM**, **daemonless**,
  and **CI-ready on GitHub Actions**. The closest (Multipass) trades a
  root snap daemon and Ubuntu-image lock-in for it; the healthiest
  (Lima) structurally owns the user-data and cannot pass it through.
- `qemu-vm.sh` is therefore a product, not a reinvention — it is
  cloud-init's own upstream-documented QEMU pattern with lifecycle glue
  nobody has productized in this shape.
- It moves to its own repository (`cur8s/qemu`) with three consumption
  channels: **vendored copy with a provenance header** for sibling
  repos, **immutable GitHub Releases + checksums** for public
  consumers, and a **composite action** (`uses: cur8s/qemu/action@v1`)
  for CI.
- Rejected mechanisms: git submodules (per-consumer auth plumbing for
  private repos; ergonomics), git subtree (whole-tree imports, merge
  noise), Carvel vendir (maintenance-mode project; asks every consumer
  to install a niche binary for one file).

---

## Report A — the existing-tool landscape

Requirements profile evaluated for every tool:

- **C1** plain `#cloud-config` user-data as the primary interface,
  portable to real clouds
- **C2** macOS Apple silicon (hvf/vz) and Linux KVM, one workflow
- **C3** GitHub Actions ubuntu-latest friendly: no daemon, no root
  beyond apt, scriptable create → wait → ssh → destroy
- **C4** lightweight/daemonless, no image lock-in
- **C5** multiple VMs on a shared private network without root

### Ground truth about the CI substrate

- `/dev/kvm` is usable on **all standard x64 ubuntu-latest runners,
  public and private repos**, since GitHub's 2024-04-02 changelog
  extended hardware acceleration to the 2-vCPU (private-repo) SKU. One
  udev rule opens it (GitHub's own snippet):
  `KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"`.
  Caveat: GitHub frames this as Android-emulator acceleration and has
  declined to document general nested-virt support — policy-by-practice,
  not SLA.
- GitHub-hosted **macOS arm64 runners have no nested virtualization**
  (Apple Virtualization.framework limitation, per GitHub docs). The
  macOS leg of any VM workflow cannot be CI-tested on hosted runners.

### Tool-by-tool verdicts

**Lima (limactl)** — CNCF Incubating, monthly releases; the healthiest
project surveyed. C2 yes, C3 yes (official lima-actions), C5 yes — its
`user-v2` network is the only production-grade rootless VM↔VM fabric
found. But **C1 is a verified hard no**: Lima generates and owns its
cloud-init user-data from an internal template (checked to source);
discussion #1520 shows a user forking Lima to inject custom user-data,
and PR #2271 moved the opposite direction. Adopting Lima means
rewriting provisioning into its YAML — abandoning "the same file
provisions the droplet."

**Canonical Multipass** — the mirror image. **C1 yes**:
`multipass launch --cloud-init file.yaml` passes user-data through
(with vendor-data layered the same way real clouds do); cloud-init
upstream documents it as the recommended local runner. C2 yes. But C4
no: an always-on privileged `multipassd`, snap-only on Linux,
effectively Ubuntu-image-only. C3 partial (works with snap+udev on
runners, little real-world usage). Project alive but patch-only for a
year, blueprints/LXD/libvirt drivers deprecated. **Verdict: the honest
fallback if maintaining our script ever stops being worth it — the one
tool that preserves the cloud-init contract.**

**quickemu** — automates attended desktop/ISO installs, not headless
cloud-image provisioning; no cloud-init. Wrong tool class.

**virter (LINBIT)** — right idea (cloud images, CI orientation), but
Linux/libvirt only and provisioning goes through its own TOML DSL; the
internal user-data is a hardcoded template. Fails C1 and C2.

**kcli** — very active, enormous scope (libvirt through AWS/GCP/
KubeVirt, `create cluster` for k3s etc.), but cloud-init is generated
from kcli's params, macOS means a remote libvirt, and everything rides
root libvirtd. A lab platform, not a light wrapper; the reference point
if we ever accept libvirt for multi-node work.

**Tart (cirruslabs)** — Apple-silicon-host-only, OCI-distributed images
with baked credentials, cloud-init declined ("not planned"), Fair
Source license with org-size gate. Solves a different problem (macOS
guests in CI on Mac hardware).

**Vagrant (+ vagrant-libvirt / vagrant-qemu)** — box-format lock-in,
`cloud_init` experimental for ~6 years and VirtualBox-documented only,
vagrant-libvirt Linux-only, arm64-macOS story fractured
(one-maintainer vagrant-qemu, paid Parallels), stewardship signal weak
post-IBM. Strictly worse than the script for this profile.

**The classics** — `cloud-localds` (healthy; exists solely to turn
`#cloud-config` into a NoCloud seed — it *is* one function of our
script, and the only clean C4 score in the survey), `virt-install
--cloud-init` (real raw user-data support but married to libvirtd;
session mode cannot do inter-VM networking), `uvt-kvm` (Ubuntu-only,
sleepy). They confirm the cloud-init-first pattern but are all welded
to Linux and the root daemon.

**2024–2026 newcomers** — **macadam** (crc-org): the only tool with the
exact intended shape — raw `--cloud-init` NoCloud passthrough on a
cross-platform daemonless CLI — but 33 stars, podman-machine baggage,
no CI or networking story; re-check in twelve months. **smolvm**:
libkrun microVMs from OCI images; cloud-init is a wontfix — different
paradigm. **Holos**: "docker compose for kvm/qemu," nails C1+C5 with
socket-multicast rootless VM↔VM — but Linux-only and weeks old.
**vmactions** family: boots BSD/Solaris guests via QEMU on
ubuntu-latest — validates the CI pattern; no Ubuntu guest because
Ubuntu is the host.

### Summary table

| Tool | C1 cloud-init | C2 macOS+Linux | C3 GHA | C4 light | C5 multi-VM |
|---|---|---|---|---|---|
| Lima | No (verified) | Yes | Yes | Partial | Yes (user-v2) |
| Multipass | Yes (YAML-only) | Yes | Partial | No | Partial-Yes |
| quickemu | No | Partial | No | Partial | No |
| virter | Partial (TOML DSL) | No | Partial | Partial | Partial |
| kcli | Partial | Partial | Partial | No | Partial |
| Tart | No (declined) | No | No | Partial | Partial |
| Vagrant+libvirt | No | No/Partial | Partial | No | No/Partial |
| virt-install | Yes | No (practically) | Partial | No | No |
| cloud-localds + qemu (DIY) | Yes | Partial | Yes | Yes | Partial |
| macadam | Yes | Yes | Unknown | Partial | No |
| smolvm | No (wontfix) | Yes | Likely | Yes | No |
| Holos | Yes | No (Linux-only) | Partial | Yes (Linux) | Yes (Linux) |

### Engineering flags for the roadmap

- **Multi-VM networking (C5)**: the obvious rootless answer on Linux
  (`-netdev socket,mcast=`) has a primary-source negative report on
  macOS hosts; QEMU 7.2's `dgram`/`stream` netdev backends are the
  cross-platform rootless avenue to prototype. Lima's user-v2
  (gvisor-tap-vsock) is the existence proof that rootless VM↔VM is
  solvable.
- **KVM on runners is policy-by-practice**: it works everywhere today
  (public and private), but GitHub documents it only as Android
  acceleration.

---

## Report B — distribution mechanics for a single-file tool

### Vendoring by copy is a first-class idiom

- **GNU config.guess/config.sub** define the provenance-header
  convention: version stamp, canonical upstream URL, "send patches
  upstream" — i.e., *version + upstream + don't fork locally*.
  Automake's `install-sh` (`scriptversion=`) same.
- **gradlew/mvnw**: the canonical committed wrapper scripts — Gradle
  docs instruct checking them into version control; the pin lives in a
  sidecar properties file and upgrades are tool-mediated
  (`./gradlew wrapper --gradle-version X`), never hand-edited.
- **shunit2, eficode/wait-for, bashunit, git-prompt.sh**: single-file
  tools whose own docs bless the copy.
- Systemic proof: **GitHub Linguist's `vendor.yml` hardcodes `gradlew`,
  `mvnw`, `config.guess`, `config.sub` as vendored paths** — committing
  such files is standard enough that GitHub excludes them from language
  stats.

Convention adopted: config.guess-style header (version, upstream URL,
"do not edit here; update with: `<command>`") plus a one-command,
tool-mediated refresh.

### curl-pinning raw.githubusercontent.com

Workable for **public** consumers only, pinned to a **full SHA** with a
published sha256. Reasons for caution, all verified: GitHub tightened
unauthenticated rate limits explicitly covering raw downloads
(changelog 2025-05-08; no published numbers; per-IP enforcement and
GitHub-hosted runners share egress IPs); the raw domain is
Fastly-fronted with a 5-minute cache on mutable refs; auth on the raw
domain is contested/undocumented. For private repos the supported path
is the Contents API
(`gh api -H "Accept: application/vnd.github.raw" repos/ORG/REPO/contents/FILE?ref=SHA`) —
and the default `GITHUB_TOKEN` cannot read *any other* private repo,
which shapes everything below.

Security history that dictates SHA-pinning: **Codecov Bash Uploader**
(2021 — hosted script silently modified, CI env exfiltration, caught by
a customer comparing checksums) and **tj-actions/changed-files**
(CVE-2025-30066, March 2025 — version tags retroactively moved to a
malicious commit, ~23k repos leaked secrets; SHA-pinned consumers
unaffected). GitHub: "Pinning an action to a full-length commit SHA is
currently the only way to use an action as an immutable release."
**Immutable releases went GA 2025-10-28** — tag and assets locked at
publish; the mitigation to adopt.

### Submodules, subtree, vendir — rejected with reasons

- **Submodules**: bats-core officially recommends them (the one
  respected precedent), but the costs dominate for one file: documented
  ergonomic traps (detached HEAD, empty dirs, pull not updating), and —
  decisive for a private org — the default `GITHUB_TOKEN` cannot fetch
  other private repos, so *every consumer repo* needs PAT/deploy-key/
  GitHub-App plumbing to import one file.
- **Subtree**: no path filtering (imports the whole upstream tree),
  merge-commit noise, poorly known commands, nothing marks the vendored
  file as foreign. Bitcoin Core makes it work with custom lint tooling
  — overkill here.
- **Carvel vendir**: mechanically the best declarative fit
  (`includePaths` a single file, lockfile, Renovate support) but the
  project has been in maintenance mode since Broadcom's May 2024
  layoffs (CNCF health review closed without archiving; releases slow),
  adoption outside Tanzu is minimal (~386 `vendir.yml` on all of
  GitHub), and requiring consumers to install a life-support binary to
  sync one file is a poor social trade. The hand-rolled equivalent — a
  pinned `gh api` fetch in a refresh task — gives the same benefit with
  zero consumer tooling.

### Composite action — the CI fit

All mechanics verified against docs and the runner's source:

- `uses: {owner}/{repo}/{path}@{ref}` subdirectory actions are
  first-class; the runner downloads the entire repo tarball at the ref,
  so the script ships with the action; `${{ github.action_path }}` is
  the documented way to reach it.
- **Private same-org sharing without PATs** (GA Dec 2022): provider
  repo Settings → Actions → Access → "Accessible from repositories in
  the organization"; GitHub mints a scoped one-hour read token for
  `uses:` resolution.
- `sudo apt-get` in composite steps is sanctioned (passwordless sudo is
  a documented runner property); installer-actions are an established
  genre.
- Constraints: no `secrets` context (inputs only), no `runs.post`
  cleanup (fine — the VM dies with the ephemeral runner; VM actions
  needing guaranteed teardown are node wrappers for exactly that
  reason), no per-step timeout, `shell:` required on every run step,
  steps collapse to one log line for the consumer.
- Precedents: **lima-vm/lima-actions** (composite actions in
  subdirectories, moving `v1` tag), docker/setup-qemu-action,
  medyagh/setup-minikube.
- Versioning norm (actions/toolkit): tag semver, consumers bind `@v1`,
  maintainer force-moves the major tag per release; publish `vX.Y.Z`
  as immutable releases; never reference main.

**Composite action beats a reusable workflow here** because the VM's
lifetime is the job's lifetime: consumers must run their own steps
against the booted VM in the same job — composite gives that; a
reusable workflow replaces the whole job and would take the consumer's
commands as a string input. (Reusable workflows also must live flat in
`.github/workflows/` — no subdirectories.) A thin reusable workflow
wrapping the action is an optional later add-on. Org starter templates
copy-then-drift; skipped.

### The recommendation matrix

| Consumer | Mechanism |
|---|---|
| Sibling repos (local/dev use) | Vendored copy with provenance header; refresh via pinned `gh api` one-liner |
| Unknown public consumers | Immutable GitHub Releases (script + sha256 asset); README curl-by-SHA one-liner |
| GitHub Actions CI | Composite action `uses: cur8s/qemu/action@v1`; example workflow in README for those who prefer owning the lines |

Gotchas recorded for the implementation: include
`OPTIONS+="static_node=kvm"` in the udev rule; no KVM on arm64/macOS/
Windows runners; `@v1` is a mutable pointer by design — immutable
`vX.Y.Z` releases are the integrity anchor; Dependabot/Renovate close
the update loop for `uses:` pins.

---

## How this fed the product

`cur8s/qemu` implements: the script as the single vendorable artifact
with a config.guess-style header; a composite action in `action/`;
dogfood CI on ubuntu-latest KVM; release flow targeting immutable
releases with sha256 assets and a moving `v1`; and a roadmap item for
rootless multi-VM networking via QEMU `dgram`/`stream` backends (the
multi-node k3s rig). This repository (`cur8s/ubuntu`) is consumer #1,
vendoring the script by copy under `scripts/`.

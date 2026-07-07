# Architecture Guide

This guide builds the mental model of the baseline end to end: the
problems it solves, how the pieces fit, and where each one is pinned
down. It is the map, not the territory. The RFCs in `docs/rfcs/` are the
normative source of truth and the code is the implementation; where this
guide and an RFC disagree, the RFC wins. Read this first for the shape,
then follow the pointers into the RFCs for the contract and the full
reasoning.

Every section states a problem the baseline has to solve, then how it
solves it, then where the detail lives.

## How to read this

The documentation has four registers, and knowing which you're in saves
time. **This guide** is the map — narrative, non-normative, the
recommended first read. **The RFCs** (`docs/rfcs/`, numbered 000–011 in
reading order) are the law: what must stay true and why. **The other two
guides** own the how — the user guide for consuming the baseline, the
developer guide for changing it. **Notes** (`docs/notes/`) are evidence
and discarded roads; **examples** (`examples/`) are runnable and
prescribe nothing. When this guide says "→ RFC-005," that's your cue to
read the contract when you want it; you never have to, to follow the
story.

## 1. The baseline and layers

**The problem.** You've inherited forty Ubuntu servers across three
clouds. Which ones still accept password logins over SSH? Which keep
their logs after a reboot, and which quietly lose them? Which have a
forgotten contractor's key in `authorized_keys`? You cannot answer
without logging into all forty — and even then, nothing stops the
answers from drifting apart again next week. Every host is a snowflake,
the fleet has no shape you can describe, and "is this server fit for
production?" has no answer you can check.

**How the baseline solves it.** The baseline is a fixed set of
invariants that *every* managed host gets, enforced the same way on
every provider: the two access accounts, key-only SSH, security updates
that never reboot on their own, logs that survive a reboot. A host
either conforms or it doesn't — a yes/no you can check, and re-check on a
schedule, forever. The forty snowflakes become forty hosts with one
describable floor, and the question that had no answer becomes a report.

Two tiers make this work without becoming a straitjacket. The
**baseline** is the floor: minimal, always enforced, never turned off.
**Layers** are everything optional built on top — a Kubernetes node, a
database host, an access network. Being disable-able is exactly what
makes something a layer rather than baseline. The floor is deliberately
low so that anything can be built above it; nothing ever goes below it.

→ RFC-001: The Host Baseline — the two-tier model and the lifecycle.

## 2. Why the floor stays low

**The problem.** "Hardened baseline" tempts you to cram in everything
defensible: fail2ban, auditd, a firewall, a pinned time daemon, sysctl
hardening. But every setting you pin is a setting you now own forever —
it has to track upstream, and it can fight the layers above. Pin
`systemd-timesyncd` as *the* time mechanism, and the day someone builds
a host that wants chrony, the baseline uninstalls chrony out from under
them: the floor fighting the layer. A baseline that owns too much is a
bug factory.

**How the baseline solves it.** A control earns a place only if it
passes a three-part test: it's an invariant for *any* production host,
there's no legitimate reason it would ever be off, and enforcing it
can't break future workloads or lock you out. Everything else stays out.
Two disciplines follow. **Pins, not checks:** declare only what diverges
from the distro default and trust what the default already guarantees —
nothing declared means nothing to maintain. **Floors, not practices:** a
practice (a scanner's config, fleet hygiene) churns with opinion; a
floor releases only when the facts beneath it change. That's why the
baseline deliberately refuses to own time sync, auditd, firewalls, and
kernel tuning — each is a layer's business, and the baseline's job is to
not fight it.

→ RFC-002: Baseline Doctrine (the inclusion test), RFC-003: Baseline
Contents (what's in, and what's excluded and why).

## 3. Identity and trust

**The problem.** To manage a host you must get into it, and every way in
is a risk. Share one key between automation and a human, and a CI leak
costs you your emergency access too. Keep keys in the repo, and they
leak the moment the repo does — and AI agents work directly in this
repo. Trust the provider's original login forever, and you can never
really say who can get in.

**How the baseline solves it.** Two named accounts, role-scoped rather
than per-person: `ansible` is the automation door (its key lives in CI
for scheduled runs — constant use, higher exposure), and `sysadmin` is
the human break-glass door (its key never leaves the operator's secrets
manager — rare use, lower exposure). Two, so a CI compromise never costs
break-glass access and either can be rotated independently. The names
are fixed and non-overridable so that layers, ACLs, and runbooks can
hardcode them. All baseline keys are ed25519, and private keys live
*only* in the operator's secrets manager — never committed, never
written into generated files (the one narrow exception is the throwaway
lab keys, which open nothing but a disposable VM). Per-person identity
is deliberately not the baseline's job; that belongs to an access layer.

→ RFC-004: Identity and Trust.

## 4. Entering the baseline

**The problem.** A host has to *become* conformant before converge can
keep it that way, and hosts arrive two ways with opposite starting
points. A fresh cloud VM is empty. A server you inherited is a mystery:
unknown accounts, unknown SSH config, workloads you must not disturb.
One recipe can't serve both — the empty host wants "apply everything,"
the unknown host wants "look before you touch."

**How the baseline solves it.** Two on-ramps to the same conformant
state. **Born conformant:** cloud-init at first boot applies the
baseline from the very same files the Ansible roles own, so the host
arrives already conforming and the first converge is a no-op. The "same
files" part is load-bearing — if cloud-init and the roles each defined
the SSH policy separately, they would drift and the first converge would
"fix" phantom differences forever, so the drop-in is read from one
shared source. **Adopted:** for hosts that already exist, a read-only
assessment that refuses to guess — it names hard failures and exactly
what the first converge will change — followed by an additive adopt that
only *adds* the two accounts and proves them, editing nothing that
already exists. The moment `ansible` and `sysadmin` work, both on-ramps
have converged to the same place and the rest of the lifecycle takes
over unchanged.

→ RFC-006: Provisioning (born conformant), RFC-007: Adoption (the
unknown host).

## 5. Staying conformant

**The problem.** Conformance the day you set it up is worthless if it
erodes. Someone SSHes in to debug and leaves a setting changed; a
package update flips a default; an agent edits a file out of band. Six
months later the fleet has quietly diverged again and you're back to
snowflakes — unless something continuously pulls it back.

**How the baseline solves it.** Converge, forever. Desired state is
declared in git; converge enforces it over plain SSH and reverts
anything not in git, so only declared, in-git changes stick. That makes
every change attributable — the commit is the who and why, the run is
the what and when. On a healthy host every converge reports `changed=0`,
so a non-zero count *is* the drift alarm; check mode gives the same
report while touching nothing. One property makes the schedule safe to
run blind: converge enforces but never *removes* access. No routine run
closes a door — a leftover key survives until a human deliberately
removes it (§6). That is what lets a scheduled converge run against
production at any hour without ever locking anyone out.

→ RFC-008: Convergence.

## 6. The access surface and its verbs

**The problem.** The one operation that can permanently lose you a host
is removing access: close the wrong door, or close the right one before
its replacement is proven, and all that's left is the console. So the
thing you most need to do — retire an old provider login, rotate a key —
is also the thing most likely to lock you out. And a blunt rule like
"enforce exactly these two accounts, delete the rest" is worse than the
disease: it would condemn every healthy service account and outlaw the
access layers you deliberately want.

**How the baseline solves it.** Model a host's access as a set of
**doors** — anything that can be logged into — each of which must have an
**owner**: the baseline, an access layer, or an operator who can say why
it exists. The violation is the *unowned* door (the forgotten contractor
account, the deploy key nobody retired), not "more than two doors." Then
split the work into five verbs, each handed to the hands whose mistakes
are survivable: converge *enforces* (and never removes), reporting
*observes* read-only, locking *closes* named doors as a deliberate
standalone act, rotating *re-keys* one account by entering through its
sibling, and deletion is *human* work outside the collection. Every
removal of access is deliberate and standalone — never a converge side
effect — because that separation is what keeps the schedule safe.

→ RFC-005: Accounts and Access.

## 7. Knowing it works

**The problem.** A baseline that *declares* the right state hasn't
proven the host actually behaves. Does the box really come back after a
reboot with both accounts working, services up, and logs intact? You
can't answer that by reading the playbook — and you can't answer it by
rebooting production on every converge either. Verification that runs
constantly is either too weak to matter or too dangerous to run.

**How the baseline solves it.** Keep verification deliberate, not
ambient. Baseline roles declare state and don't second-guess it; proving
the promises hold is the job of opt-in acceptance gates — chiefly reboot
validation, which reboots the host and confirms access, services, and
journal history all survived the boot. Anything lockout-sensitive, like
retiring the bootstrap door, requires that gate first, so there is never
a moment without a proven way in. The tests behind all this are
organized by proof plane — fixtures (seconds, no VM), the free local VM
lab (the bulk of the coverage), and a real provider at release cadence —
each proving what the cheaper plane cannot.

→ RFC-009: Validation and Acceptance; the developer guide's Testing
section has the full test architecture.

## 8. Shipping and the stable surface

**The problem.** Consumers and layers need to build on the baseline
without their work shattering every time it changes — and they need to
know *which* baseline they're getting. If names and paths shift release
to release, every layer breaks. If the version scheme is opaque, nobody
knows what "safe to upgrade" means.

**How the baseline solves it.** Version by the Ubuntu it targets:
`24.4.x` means "the 24.04 baseline, release x," and the baseline is
forever backward-compatible within its LTS era, so `x` only ever climbs.
It ships from git only — no registry — with `main` as the production
release and tags as pinnable versions. On top of that sits a small,
explicit **conventions contract**: the account names, the playbook
FQCNs, the file paths, and the environment-variable inputs, all of which
change only through a deliberate RFC revision. That is what a layer is
allowed to hardcode — `cur8s.ubuntu.converge` and the `ansible` /
`sysadmin` names are promises, not implementation details that might
move under you.

→ RFC-010: Release and Versioning, RFC-011: Conventions Contract.

## 9. Composing on top

**The problem.** Once you start building — a k3s node, a database host,
your own site policy — where does each piece belong? Put something in the
baseline that shouldn't be there and you can't change your mind about it
without releasing the baseline. Put it too high and you re-solve it on
every host. Get this wrong and layers leak into the floor.

**How the baseline solves it.** Composition reaches only upward: a
purpose layer imports and enforces the baseline first, then adds its own
state, and the baseline never tests or promises any particular layer.
Where a thing belongs is settled by the version-pressure test — if
changing your mind about X would force a release of Y, then X does not
belong in Y. A layer with a real contract of its own (a Kubernetes
distribution, a database platform) earns its own versioned repository;
site policy — the access network your hosts join, your scanners — lives
in your environment repository. Three tiers, bottom to top: the generic
baseline (no secrets, no inventory, no schedule), purpose layers, and
deployments that own the inventory, keys, and schedule. Because every
tier enforces the baseline, it holds on every host, on every converge.

→ RFC-001: The Host Baseline (composition tiers), RFC-002: Baseline
Doctrine (the ownership doctrine and the version-pressure test).

## Where to next

- **Building or changing the repo** → the developer guide.
- **Running the baseline on your hosts** → the user guide.
- **The contract and the full reasoning** → the RFCs, `docs/rfcs/`,
  000–011 in order.

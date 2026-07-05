# RFC-005: Accounts and Access

Status: Accepted

A Linux account is three separable things: an identity processes run as, an owner of files, and something that can be logged into. The baseline's security posture rests on being precise about the third — which accounts can be entered from outside, by whom, and who is accountable for each way in.

## Two Kinds of Accounts

**Access accounts** exist to be logged into: the ways humans and automation enter a host.

**Service accounts** exist to run processes and own files. They are created by packages and purpose layers (`postgres` arrives with PostgreSQL, and a stock Ubuntu install ships dozens: `daemon`, `messagebus`, `systemd-network`, ...). They are born unable to log in: no password hash, no authorized keys, a `nologin` shell. A healthy service account stays that way forever.

The two kinds are told apart by a single question — can it be logged into? — never by name or UID range. An account with an `authorized_keys` file or an unlocked password can be; each of those is a **door**. An account with a door is an access account, whatever it is called and whatever created it.

Privilege — membership in `sudo` or `admin`, a sudoers grant — is not a door; it lets nobody in. It determines what a door is worth: a door into a privileged account is a door to root. The doors, and who holds privilege, together make up a host's **access surface**.

## What the Baseline Claims

The baseline owns exactly two doors: `ansible` and `sysadmin` (RFC-004: Identity and Trust). It enforces their full specification — ed25519 keys, locked passwords, passwordless sudo — and claims nothing about the existence of any other account. Service accounts are the purpose layers' business: the baseline never creates one, never locks one, never deletes one, and never mistakes a doorless account for a problem.

## Every Door Has an Owner

Converge makes the two baseline accounts right; that is the easy half of conformance. The hard half is everyone else: an adopted server arrives with whatever accounts its history left behind, and even a born-conformant fleet accumulates access over the years — a deploy key here, a departed colleague's account there. Judging those needs a rule, and "nothing but the two" cannot be it: that would condemn every healthy service account and outlaw the access layers the baseline deliberately leaves room for (RFC-004: Attribution).

The rule is ownership. A conformant host has the two baseline accounts to specification, and every other element of its access surface is deliberate and owned — by an access layer above the baseline, or by an operator who can say why it exists.

What violates the rule is the **unowned door**: the installer-created user nobody retired, the forgotten deploy key, a contractor account that outlived the contract, a service account that grew an `authorized_keys` file — that last one a classic persistence technique, invisible unless someone looks. The rule is not "two doors maximum"; it is that no door is an accident.

## The Verbs and Who Wields Them

Removing access is the operation that can lose a host: close the wrong door, or close the right one before its replacement is proven, and what remains is the console. That risk is why the access surface gets five distinct verbs, each assigned to the hands whose mistakes are survivable:

**Converge enforces** the two baseline accounts — and never removes access from anything: not the leftover bootstrap door, not even a foreign key found on a baseline account. This is structural, not configurable: routine convergence must be safe to run blind, on a schedule, forever (RFC-008: Convergence). Closing a door is never a side effect.

**Reporting observes** — because no door can be judged owned or unowned until someone can see it. A read-only report lays out the access surface — every door, every privilege holder, the state of previously closed doors, foreign keys on the baseline accounts — and changes nothing. Observation is deliberate, never ambient (RFC-002: Baseline Doctrine): converge does not narrate, and the report does not enforce.

**Locking closes** doors named by a human: it strips the account's authorized keys, locks its password, and removes it from privileged groups and provisioning-time sudoers grants. It is a standalone, explicitly invoked operation — never part of converge — that refuses to target the baseline accounts or the account it is connected as, and proves both baseline doors open before closing anything. A second run changes nothing.

**Rotating re-keys** a baseline door — the one operation permitted to change the keys of `ansible` or `sysadmin`. One account per invocation, entered through the sibling account so it never depends on the key it replaces (RFC-004: Identity and Trust): add the new key, prove it over SSH with sudo, then reduce the account to exactly the new key. It refuses to run if the account holds any key the baseline does not expect — rotation transitions known state to known state, and surprises summon a human. Converge never grows this power: enforcing an exact key set on a schedule would turn one bad input into a fleet lockout, so removing a key — like every removal of access — belongs only to this deliberate verb.

**Deleting is human work**, outside the collection. Deletion destroys data and attribution, and is impossible for `root`; deciding it is ordinary system administration. The collection's primitive is lock, because lock is reversible from a console; the operator's option is delete, because the judgment is theirs.

## Locked Means the Doors, Not the Identity

The hesitation before locking an account on a live host is the fear that something depends on it — a service running as it, a cron job, the files it owns. Locking touches none of that. A locked account can no longer be logged into from outside, and that is the entire change: it still runs processes (systemd starts services as an account directly; no login is involved), still owns its files, and a privileged session can still become it — acceptable, because whoever can do that already controls the host. Closing a door stops nothing the account was doing.

Locking is also reversible from a console, where deletion is not. Ending access from outside while preserving the identity, its data, and the evidence trail is why lock is the verb the tooling is trusted with.

## Scope

This RFC defines the account taxonomy, the doors model of the access surface, the baseline's claim of exactly two owned doors, the door-ownership conformance rule, and the division of verbs — enforce, observe, lock, rotate, delete — among converge, reporting, explicit invocation, and humans.

It does not define the identity roles, key policy, or bootstrap lifecycle (RFC-004: Identity and Trust), convergence semantics (RFC-008: Convergence), where verification lives (RFC-002: Baseline Doctrine, RFC-009: Validation and Acceptance), or the operational runbooks (the user guide).

## Revisions

Initial version.

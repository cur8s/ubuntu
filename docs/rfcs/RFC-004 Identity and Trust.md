# RFC-004: Identity and Trust

Status: Accepted

Password-based SSH authentication is not part of the baseline. All baseline SSH public keys use the `ssh-ed25519` OpenSSH public key type; RSA, ECDSA, DSA, and other types are not approved.

## Three Identities

The provider bootstrap user is the provider-specific first-login account: `root` on DigitalOcean, `ubuntu` on AWS and GCP Ubuntu images, the caller-defined admin username on Azure. The baseline never assumes root SSH is available and never depends on it. This identity exists to make a new host reachable before the baseline accounts are proven, and it is retired afterward.

`ansible` is the automation door. Its key is used by converge: it lives in the operator's secrets manager for ad-hoc runs and in an environment repository's CI for scheduled runs. Non-interactive, constant use, higher exposure.

`sysadmin` is the human break-glass administrator. Its key never leaves the operator's secrets manager, is human-present, and is used when the access layer is unavailable or not yet joined. Rare use, lower exposure. The durable break-glass.

## Why Two Named Accounts

Per-person attribution is the access layer's job, so both accounts are role-scoped and carry the same sudo policy. The separation exists for credential custody and blast radius: the automation key sits in CI, a higher-exposure trust zone, while the break-glass key never leaves the secrets manager. Either key can be rotated or revoked independently — a CI compromise never costs break-glass access, and vice versa.

## Why Fixed Names

`ansible` and `sysadmin` are hardcoded and non-overridable: a stable contract of the bottom layer that access-layer ACLs, log parsing, runbooks, and use-case collections can rely on with zero configuration (RFC-011: Conventions Contract). They are role names, not people, so genericity is preserved — the keys installed into them remain consumer inputs. The names are self-documenting for humans and AI coding agents. `sysadmin` also avoids concrete traps that disqualify `admin`: the Ubuntu `admin` group is a `useradd` collision, and Azure reserves the name.

## Key Custody

The repository handles public keys only. Private keys live solely in the operator's secrets manager and its SSH agent — never committed, never embedded in provisioning assets, never written to generated files. This is a hard requirement because AI coding agents work on the operator's workstation. The baseline uses a small set of well-known, reused named keys, not per-VM keys. Standing credentials appear only in a consumer's environment repository; the generic collection holds none.

One narrow exception exists: **ephemeral test credentials**. The local QEMU harness generates throwaway keypairs into git-ignored workstation state, so the local development loop runs unattended with no secrets-manager involvement. These are test fixtures, not credentials: they open nothing but a disposable VM on a loopback port, are never valid for a cloud host, never committed, and die with the workstation state. The custody rule above governs every key that opens anything real.

## Key Rotation

Keys are born and die inside the secrets manager. A replacement key is generated in the vault, so its private half never exists anywhere else; a retired key is archived there, which evicts it from the SSH agent — the step that operationally kills a credential once its public half has left the hosts. The vault's archive doubles as the audit trail.

Rotation replaces one account's key per invocation, and always enters through the sibling account: rotating `ansible` connects as `sysadmin`, and vice versa, so the operation never depends on the credential it is replacing. This is the account pair doing the job it exists for (Why Two Named Accounts): there is always a proven door the rotation cannot break, which is also why the one-account-per-invocation constraint is deliberate rather than convenient.

Host-side mechanics are the rotate verb (RFC-005: Accounts and Access): add the new key, prove it over SSH with working sudo, and only then reduce the account to exactly the new key — refusing outright if the account holds any key the baseline does not expect. Fleet completion is verified the usual way: a converge reporting zero changes and an access-surface report showing no unexpected keys.

## Bootstrap Retirement

The baseline normalizes hosts: after first boot, every host looks identical regardless of provider. Once replacement access is validated — both named accounts proven over SSH with working sudo — the provider bootstrap identity is retired by locking it (RFC-005: Accounts and Access): authorized keys stripped, provisioning-time sudoers removed, password locked, privileged group memberships removed. The account is never deleted; deletion is provider-specific, and provider tooling may assume it exists.

Retirement is a deliberate, standalone invocation, never a converge side effect: development environments keep the provider door as a debug path, production closes it when ready. The lock operation itself re-proves both named accounts before closing anything, and retirement belongs only in environments that have passed reboot validation (RFC-009: Validation and Acceptance) — there is never a moment without a proven access path. After retirement, recovery is the provider console.

## Attribution

Baseline attribution is role-level — automation versus human — plus what, when, and why from git and converge history (RFC-008: Convergence). Per-person identity, session recording, and identity-aware SSH belong to an access layer. The baseline's only obligation to any access layer is to not fight it: keep OpenSSH for bootstrap and break-glass, and keep the account model per-person capable.

## Scope

This RFC defines the identity roles, key policy, custody rules, the key rotation lifecycle, and the bootstrap retirement lifecycle.

It does not define the OpenSSH server policy (RFC-003: Baseline Contents), provisioning mechanics (RFC-006: Provisioning), or the operational workflow (the guides). It governs OpenSSH public keys, not OpenSSH user certificates.

## Revisions

Initial version. Consolidates the retired SSH Key Strategy draft; the human administrator account is `sysadmin`, renamed from the earlier `admin`.

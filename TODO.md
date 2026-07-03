# TODO — cur8s.ubuntu

Open work only, in priority order. `[~]` in progress · `[ ]` not started.
Completed work lives in git history and the RFC Revisions blocks.

## 1. Prove the three-tier composition (RFC-001, RFC-006)
- [ ] Build `cur8s.k3s` (in `~/dev/cur8s/k3s`): a use-case collection that depends on `cur8s.ubuntu` via git, whose converge runs `import_playbook: cur8s.ubuntu.converge` first and then applies the k3s role. Steel thread: fresh droplet → converge → baseline no-op + k3s installed → second converge `changed=0` → node `Ready` → `cur8s.ubuntu.validate_reboot` + node `Ready` after reboot.

## 2. Executable examples (ported from the archived prototype)
- [~] Port the archived example playbooks into `examples/<name>/` dirs, each re-asserting the baseline first and runnable against the lab VM (`mise run example:run <name>`; working-tree collection resolved via the `.generated` symlink). Index with themes + techniques in `examples/README.md`. Done: **docker**, **zot**, **postgres**. Remaining, in porting order: **lynis** + **osquery**, **tailscale** (install + join; secret via env var, overlaps future `cur8s.tailscale`).

## 3. Conventions contract (RFC-009)
- [~] RFC-009 is `Status: Draft` with the first enumeration written. Promote to Accepted once `cur8s.k3s` has consumed the contract and proven it sufficient; add whatever the consumer turned out to need.

## 4. First release (RFC-008)
- [ ] Cut `v24.4.0` when the composition proof lands: bump nothing (version already `24.4.0`), tag, `git push origin main --tags`, then pin the tag in `examples/requirements.yml` and the manual's install snippets.

## 5. Cleanup
- [ ] Remove the local `archive/` reference copy (untracked + gitignored) once done mining it — `rm -rf archive/`. Git history preserves it (deleted in `685bf88`, restored locally 2026-07-03 for the RFC rewrite).

## Separate work (other repos)
- `cur8s.tailscale` collection (opt-in access layer; the canonical dogfood consumer).
- Optional Multipass local-dev loop for gateway-free iteration on the same cloud-init render.
- Bare-metal `autoinstall` wrapper (nest the cloud-config under `autoinstall.user-data`, seed via NoCloud) — RFC-005 sketches it.

## Key files
- `docs/rfcs/` — the RFC series (start at RFC-000; architecture source of truth)
- `docs/operations/manual.md` — the operations manual
- `docs/notes/ucg-fibre-ips-ssh-blocking.md` — the IPS incident that drove the cloud-init design
- `collection/playbooks/cloud-init/render.sh` — cloud-init generator (RFC-005)
- `collection/playbooks/converge.yml` — converge entrypoint

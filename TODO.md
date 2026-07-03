# TODO — cur8s.ubuntu

Open work only, in priority order. `[~]` in progress · `[ ]` not started.
Completed work lives in git history and the RFC Revisions blocks.

## 1. Bare-metal autoinstall + QEMU test harness (in progress next)
- [ ] Add autoinstall support and a QEMU-based lab to test it locally: render an autoinstall seed that nests the existing cloud-config under `autoinstall.user-data` (RFC-005 already sketches this; reuse `collection/scripts/render-cloud-init.sh` output — one source, three moments), seed via the NoCloud datasource, and drive install/boot/verify through a new `mise-tasks/qemu/` task family (the file-task migration was done to make room for exactly this). End state: the same steel thread — install → first boot → converge no-op — proven on a QEMU VM without a cloud provider.

## 2. Server adoption (after autoinstall local testing)
- [ ] Implement adoption of existing Ubuntu 24.04 servers (bare metal without the baseline accounts): read-only `adoptable` assessment + additive `adopt` playbook, per the design in `docs/notes/adopting-existing-servers.md`. Starts only once the QEMU/autoinstall lab exists (it provides the local test bed for adoption too). Re-validate the design against the code when picked up; includes the deferred key-drift-reversion and retirement sudo-group questions recorded there.

## 3. First release (RFC-008; after adoption)
- [ ] Cut `v24.4.0` once adoption lands: bump nothing (version already `24.4.0`), tag, `git push origin main --tags`, then pin the tag in `examples/requirements.yml` and the manual's install snippets.

## Key files
- `docs/rfcs/` — the RFC series (start at RFC-000; architecture source of truth)
- `docs/operations/manual.md` — the operations manual
- `docs/notes/ucg-fibre-ips-ssh-blocking.md` — the IPS incident that drove the cloud-init design
- `collection/scripts/render-cloud-init.sh` — cloud-init generator (RFC-005)
- `collection/playbooks/converge.yml` — converge entrypoint

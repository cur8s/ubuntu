# Adoptability verdict fixtures

Every verdict the adoption assessment can render, proven in seconds
without a VM:

```sh
ansible-playbook collection/tests/adoptability/verify-verdicts.yml
```

(from the repo: `mise run test:adoption-verdicts`)

Each file in `cases/` is one world: the `adopt_observations` a host
like that would produce (the probe/verdict seam — shape documented in
`playbooks/tasks/adoptability-probe.yml`) and the exact verdict it must
receive. The assertions match the stable bracketed verdict codes and
whether the refusal fires (RFC-007: Adoption); the prose around a code
may be reworded without touching a case.

`keys/` holds throwaway fixture public keys — test data, not
credentials; no private halves exist anywhere. Case filenames are
illustrative, not contract: only the verdict codes and the exit
behavior are contract surface (RFC-011: Conventions Contract).

What this layer deliberately cannot prove — that the probes read real
files correctly, that the playbooks exit nonzero at the shell, and that
adopt refuses without adding anything — is proven on a live VM by the
repo's refusal rehearsal (`mise run test:adoption-refusals`).

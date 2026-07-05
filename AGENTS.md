# Agent instructions — cur8s.ubuntu

The RFCs in `docs/rfcs/` are the normative contract and win every
conflict. For anything beyond a trivial change, read
`docs/guides/developer-guide.md` first — it is the long-form version of
this page. The essentials:

- **Design before code.** Propose and align in conversation; the operator
  approves designs — and RFC changes land as their own reviewed commit —
  before implementation starts.
- **Prove before commit.** Demonstrate every change live on the QEMU lab
  (`mise run qemu:up` — fully unattended, no 1Password). The idempotency
  contract: run it twice, the second pass must report `changed=0`. Put
  the recap evidence in the commit message.
- **Names are the interface.** Task grammar is
  `<provider>:<object>:<action>` (the `mise.toml` header is
  authoritative); names read as sentences; descriptions say only what the
  name cannot. "Confusing" is a defect — rename until it reads plainly.
- **Converge never removes access.** Closing doors, rotating keys — every
  access removal is a standalone deliberate playbook (RFC-005: Accounts
  and Access), never a converge side effect.
- **Docs move with the change**: the user guide for consumer-facing
  behavior, the developer guide for repo workflows, RFC-011 for any new
  contract surface. Pre-release, RFCs are edited in place with no
  revision-history noise.
- **Never push, and never create billable cloud resources (cloud VMs),
  unless explicitly asked.**

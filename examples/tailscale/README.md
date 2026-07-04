# Example: Tailscale

Installs Tailscale from its apt repository and joins the host to a tailnet
with Tailscale SSH enabled — a working sketch of the management-network
access layer (`docs/notes/management-network.md`), layered on the
baseline. The real product for this concern is the future `cur8s.tailscale`
collection; this example preserves the techniques.

Techniques demonstrated:

- **Vendor-hosted keyring and repo files** — Tailscale publishes both the
  binary keyring and the `.list` file; two `get_url` tasks, no dearmoring.
- **Secret input via environment variable** — the auth key never touches
  the repository or the collection (RFC-004): it flows from the operator's
  secrets manager through `TAILSCALE_AUTHKEY`, and the join task is
  `no_log` so it never lands in output either.
- **Stateful idempotent join** — probe `tailscale status`, require the
  secret only when the host is not yet joined, act only on divergence
  (join, or enable SSH on an already-joined host), then assert the outcome.
- `--accept-dns=false` keeps the example from rewriting the lab VM's DNS.

Run against the lab VM (droplet must exist — see the developer guide):

```sh
TAILSCALE_AUTHKEY="$(op read 'op://devops/ubuntu-tailscale-auth-key/password')" \
  mise run do:test:tailscale
```

Re-runs need no auth key once the host is joined (`mise run do:test:
tailscale` alone reports `changed=0`).

Cleanup note: deleting the droplet does not remove its node from the
tailnet. Remove it in the Tailscale admin console unless the auth key was
ephemeral (ephemeral nodes remove themselves when they go offline).

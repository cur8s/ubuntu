# Example: osquery

Installs [osquery](https://osquery.io/) from its apt repository for
interactive inspection (`osqueryi`), with the shipped daemon deliberately
kept off, layered on the baseline.

Techniques demonstrated:

- **Install a package, refuse its daemon** — the package is wanted for its
  interactive tool, not its service. `osqueryd` is stopped and disabled if
  present, and `service_facts` + asserts prove it stays down. The inverse
  of the usual install-and-enable pattern.
- **Keyring dance variant** — ASCII key → `gpg --dearmor` →
  `signed-by=` `.list` repo (see the lynis example for the annotated
  version).

Run against the lab VM (droplet must exist — see the operations manual):

```sh
mise run example:run osquery
```

Then inspect interactively: `mise run ssh:sysadmin`, then e.g.
`osqueryi "select * from listening_ports;"`.

The first play re-asserts the baseline (RFC-001); the second installs
osquery. Run it twice: the second run should report `changed=0` end to end.

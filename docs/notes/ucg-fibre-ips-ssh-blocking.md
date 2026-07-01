# Note: UCG Fibre IPS blocks the initialization SSH burst

Status: Note

Date: 2026-07-01

This note records a problem that intermittently broke `mise run vm:init`, the
investigation that traced it to the developer's local network gateway rather than
the host or the cloud provider, and the motivation to move host bootstrap from an
SSH-driven Ansible flow to a boot-time cloud-init flow.

## Summary

The UniFi Cloud Gateway Fibre (UCG Fibre) on the developer's home network runs an
Intrusion Prevention System (IPS). Its "Scanning Activity" signature classifies a
short burst of new SSH (TCP port 22) connections from one source as a port scan
and silently drops further packets to the destination for a cooldown window. The
initialization workflow opens exactly such a burst, so the gateway clipped the
connections mid-run. The host and DigitalOcean were never at fault.

## Symptom

`mise run vm:init` failed non-deterministically. A representative failure was the
`admin` post-lockdown validation timing out at the TCP layer while the `ansible`
validation moments earlier had succeeded:

```
TASK [Validate SSH and passwordless sudo for admin on 159.203.37.214]
fatal: [... -> localhost]: FAILED! => {... "rc": 255,
  "stderr": "ssh: connect to host 159.203.37.214 port 22: Operation timed out"}
```

`Operation timed out` is a TCP connect timeout: the SYN was dropped and nothing
answered. That is a packet-drop signature, not an authentication or SSH-layer
failure. The same command run by hand a short time later succeeded and reached
`sudo -n /usr/bin/true` with exit status 0, so the drop was transient.

## Investigation

Each candidate was eliminated with evidence collected on the host and from the
provider:

| Suspect | Result |
| --- | --- |
| Host firewall (`ufw`) | inactive |
| `fail2ban` | inactive, and no leftover iptables chains |
| `iptables` / `nftables` rules | no `DROP`, `REJECT`, `limit`, or `recent` rules |
| `sshd` throttling | default `maxstartups 10:30:100`, `persourcemaxstartups none`; the serial workflow is nowhere near the concurrency threshold |
| DigitalOcean Cloud Firewall | `doctl compute firewall list` returned no firewalls |
| SSH keys / sudo | key accepted on first offer; `sudo -n` returned 0 |

With the host and provider clean, the drop had to be on the network path. The
behavior — a burst of connections from one source IP causing all subsequent
connections to that destination to time out, then recovering after roughly 30 to
60 seconds of idle, affecting every user and key — is the signature of a stateful,
per-source connection-rate limiter in front of the host.

The developer's gateway is a UCG Fibre, and its threat log confirmed the cause.

## Root cause

The UCG Fibre IPS blocked the workstation's SSH connections to the test droplet
under the "Scanning Activity" policy.

```
Top Triggered Policies
  Scanning Activity            160
  CINS Army Reputation List      1

Adib-M2-Max -> 159.203.37.214  SSH  Scanning Activity  Intrusion Prevention  Block
  (repeated, timestamps aligned with the failed runs)
```

All 160 "Scanning Activity" blocks were SSH from the workstation to the test
droplet, timestamped to the test bursts. The single "CINS Army Reputation List"
entry was unrelated: it flagged return traffic from a *different* DigitalOcean IP
that the workstation had connected to earlier. DigitalOcean recycles public IPs
between customers quickly, and recycled IPs frequently sit on reputation
blocklists, so that alert was expected noise from the create-and-destroy testing
loop, not a second problem.

## Why the current architecture provokes it

The IPS fires on many new port-22 connections from one source in a short window.
The initialization design maximizes that pattern:

- The developer workstation, behind the IPS, is the Ansible control plane, so
  every SSH connection crosses the gateway.
- The bootstrap-then-lockdown flow reconnects repeatedly, and the access
  validation shells out to a fresh `ssh` process per user, per play.
  `playbooks/initialize.yml` validates `ansible` and `admin` in two separate
  plays, which doubles the fresh-connection count.
- Testing creates and destroys droplets repeatedly. Each throwaway droplet has a
  new IP and runs the full burst again, so a day of iteration produces hundreds of
  new SSH connections to DigitalOcean ranges — which is what a scanner looks like.

Ansible's own module connections are not the main contributor because
`ansible.cfg` sets `ControlPersist=60s`, so role tasks multiplex over one
connection. The uncontrolled part is the raw per-user validation `ssh` calls and
repeated interactive `mise run ssh:*` logins.

## Motivation for cloud-init

Working around this on the gateway is unattractive. A per-IP IPS exception must be
updated on every rebuild because the droplet IP changes each time, and a fresh IP
could be reputation-flagged on its own. Disabling or downgrading Threat Management
network-wide trades away real protection. The durable fix is to stop originating a
burst of SSH connections from behind the gateway.

Cloud-init does exactly that. A `#cloud-config` passed as instance user-data runs
at first boot, on the machine, as root, with no SSH from the workstation. It can
create the `ansible` and `admin` users with their `ssh-ed25519` authorized keys
and passwordless sudo, and write the same `sshd_config.d` baseline drop-in that
`roles/ssh` installs today. The three-play `initialize.yml` bootstrap collapses
into one file that runs before anyone connects, and validation shrinks to a single
login per user (or `cloud-init status --wait`) rather than a raw `ssh` per user per
play.

This removes the provisioning burst almost entirely, so the IPS never sees a scan
and the gateway needs no changes. Ansible keeps its role: `converge.yml` continues
to manage app-level state over one persistent `ansible` connection. The local
development loop can run the same cloud-config against a local VM (for example
Multipass, which consumes cloud-init user-data natively), so day-to-day iteration
never crosses the WAN or the gateway at all.

## Portability: DigitalOcean and bare-metal autoinstall

The reusable core of the cloud-config — `users` with keys and sudo, the
`write_files` sshd drop-in, and the `runcmd` validation — is portable, because
Ubuntu's bare-metal automated installer (Subiquity autoinstall) is itself
delivered through cloud-init. The difference is the wrapper and the delivery
mechanism, not the host configuration.

| Target | What you provide | How keys/users are applied | Delivery |
| --- | --- | --- | --- |
| DigitalOcean droplet | the `#cloud-config` directly | at first boot | droplet user-data (`doctl ... --user-data-file`) |
| Bare-metal Ubuntu | an `autoinstall` document with the same cloud-config nested under `user-data:` | install-time for the sshd/identity, first boot for the nested `user-data` | NoCloud datasource: USB volume labeled `cidata`, an HTTP-served `user-data`/`meta-data` pair, or PXE; selected via the `autoinstall ds=nocloud...` kernel argument |

So yes — a bare-metal install can come up with the keys and users already in
place. The plan is:

- Keep the users/sshd portion as a standalone `#cloud-config` for DigitalOcean.
- For bare metal, wrap it: an `autoinstall.yaml` describes the install itself
  (locale, storage, network), sets `autoinstall.ssh.authorized-keys` and
  `allow-pw: false` so the freshly installed system is reachable, and embeds the
  same user/sudo/sshd cloud-config under `autoinstall.user-data` so first boot
  reproduces the identical host state.

A plain runtime `#cloud-config` is not by itself a valid autoinstall file; it must
be nested inside an autoinstall document for the installer. But the host-shaping
content is written once and reused across both paths.

## Decision and next steps

The direction is to move host bootstrap and the OpenSSH baseline into a cloud-init
`#cloud-config`, keep Ansible for convergence, and develop against a local VM to
avoid the gateway during iteration.

Concrete follow-up work, to be reviewed before implementation:

1. Add a cloud-config template rendered from the extracted public keys, keeping
   1Password as the source of truth and private keys out of the repository.
2. Update `vm:create` to pass the rendered file as droplet user-data.
3. Add a local `vm:init`-equivalent that launches a Multipass VM from the same
   file for gateway-free iteration.
4. Reduce access validation to a single connection per user.
5. Decide what `initialize.yml` and `roles/ssh` retain: cloud-init bootstraps the
   baseline at first boot, and the role can stay to keep enforcing it on
   convergence.

## References

- `playbooks/initialize.yml` — the current three-play SSH bootstrap being replaced.
- `roles/ssh/tasks/main.yml` — the baseline `sshd_config.d` drop-in reproduced in cloud-init.
- `docs/rfcs/RFC-000 SSH Key Strategy.md` — the three-key strategy the cloud-config keys map to.

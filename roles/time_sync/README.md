# time_sync role

This role owns the baseline time-synchronization posture for Ubuntu hosts.

It asserts the Ubuntu 24.04 default rather than replacing it: the
`systemd-timesyncd` package is installed, the service is enabled and active,
and `timedatectl` reports the clock as NTP-synchronized. On a healthy default
image every task is a no-op; the role exists so converge notices when a host
has drifted away from that default (package removed, service masked, sync
broken).

timesyncd is an SNTP client, which is all the baseline needs — a correct
clock for TLS, logs, and apt. Running chrony (a full NTP implementation,
useful when a host must serve time or discipline the clock more tightly) is a
use-case decision layered on top of the baseline, not part of it.

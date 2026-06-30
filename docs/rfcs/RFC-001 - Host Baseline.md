RFC-001: Host Baseline

Status: Accepted

This repository defines a Host Baseline for Ubuntu Server systems.

The Host Baseline is the opinionated set of operating system conventions that every managed host is expected to follow. A machine either conforms to the baseline or it does not.

Architectural Boundary

The baseline governs the operating system itself. It does not define platform- or application-specific software.

Software whose primary responsibility is to provide workload-specific behavior belongs outside the baseline, regardless of how commonly it is deployed. Expanding the baseline requires architectural justification; convenience for a particular workload is not sufficient.

Scope

This RFC establishes the existence, purpose, and architectural boundary of the Host Baseline.

It does not define the specific conventions that comprise the baseline. Those conventions are established by subsequent RFCs.

Revisions

Initial version.
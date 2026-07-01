RFC-002: Baseline Ubuntu Release

Status: Accepted

Ubuntu publishes a new Long Term Support (LTS) release every two years. The natural temptation is to adopt the newest LTS as soon as it becomes available. This repository intentionally rejects that approach.

The Host Baseline always targets the previous Ubuntu LTS, not the current one.

For example, while Ubuntu 26.04 is the current LTS, the Host Baseline continues to target Ubuntu 24.04. The baseline advances to Ubuntu 26.04 only after Ubuntu 28.04 has been released.

An operating system release is only one part of a much larger ecosystem. Kernels, package repositories, drivers, third-party software, documentation, operational practices, and community knowledge all evolve around it. A newly released LTS may be stable in isolation while the surrounding ecosystem is still discovering the consequences of its changes.

During the development of this repository, Linux 7.0 replaced PREEMPT_NONE with PREEMPT_LAZY as the default preemption model. That single kernel change reduced PostgreSQL throughput by approximately 50% under some workloads, even though PostgreSQL itself had not changed. The immediate mitigation required low-level kernel tuning, while PostgreSQL will require time to adapt through its own release cycle.

This repository deliberately gives the ecosystem that time by adopting the previous Ubuntu LTS rather than the current one. By the time an Ubuntu release becomes the Host Baseline, the Linux kernel, PostgreSQL, and the surrounding ecosystem have had an additional two years to discover, understand, document, and adapt to these kinds of cross-project interactions. The objective is to spend engineering effort building and operating software rather than becoming early adopters of operating system behavior.

**Scope**

This RFC defines how the Ubuntu release that forms the Host Baseline is selected.

It does not define package selection, upgrade procedures, or implementation details.

**Revisions**

Initial version.

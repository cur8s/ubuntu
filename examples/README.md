# Consuming cur8s.ubuntu

Consumer-side files, shaped like the smallest possible environment repo
(tier three in RFC-001: The Host Baseline). Copy them into your own
repository as a starting point — they are not part of the collection's
installable content.

Install the collection from git (pin a release tag once one exists —
RFC-008):

```sh
ansible-galaxy collection install -r requirements.yml
```

Then converge a host (the same environment-variable inputs the contributor
harness uses — see RFC-009: Conventions Contract):

```sh
ANSIBLE_PUB_KEY=/path/to/ubuntu-ansible.pub \
SYSADMIN_PUB_KEY=/path/to/ubuntu-sysadmin.pub \
ansible-playbook -i <host-ip>, site.yml
```

`site.yml` shows the composition pattern: re-assert the baseline first,
then add your own plays after it. Use-case collections (for example
`cur8s.k3s`) follow exactly the same pattern inside their own converge
playbook.

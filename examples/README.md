# Consuming baseline.ubuntu

Consumer-side files, shaped like the smallest possible environment repo
(tier three in RFC-001: The Baseline Collection). Copy them into your own
repository as a starting point — they are not part of the collection's
installable content.

Install the collection from git at a pinned tag:

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

`site.yml` shows the composition pattern: re-assert the baseline floor first,
then add your own plays after it. Use-case collections (for example
`baseline.k3s`) follow exactly the same pattern inside their own converge
playbook.

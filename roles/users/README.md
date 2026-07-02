# users

Creates the fixed baseline Ubuntu users `ansible` and `sysadmin` with locked passwords, one `ssh-ed25519` authorized key each, and passwordless sudo.

This role intentionally does not know about 1Password, DigitalOcean, or any other provider. Callers pass public keys as role variables.

The account names are not configurable. Consumers of the collection provide key material for the fixed baseline accounts; they do not choose user names.

## Variables

The role has exactly two public inputs:

```yaml
ubuntu_users_ansible_public_key: ssh-ed25519 ...
ubuntu_users_sysadmin_public_key: ssh-ed25519 ...
```

The role applies fixed baseline policy: it creates `ansible` and `sysadmin`, gives both `/bin/bash`, locks passwords, installs one `ssh-ed25519` public key per user, and grants passwordless sudo.

## Task Layout

`tasks/main.yml` validates both public keys before changing the host, then explicitly configures the fixed `ansible` and `sysadmin` accounts through one role-internal task file:

* `configure-user.yml`

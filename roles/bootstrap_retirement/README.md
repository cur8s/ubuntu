# bootstrap_retirement role

Retires the provider bootstrap identity (`root` on DigitalOcean, `ubuntu` on
AWS/GCP, the `--admin-username` on Azure) once the baseline access contract is
proven: strips its `authorized_keys`, removes the cloud-init combined sudoers
file (`90-cloud-init-users`; the baseline accounts use their own per-user
files), and locks the account's password. The account is locked, never
deleted — provider tooling may assume it exists.

Safety model (RFC-004: Identity and Trust; RFC-007: Validation and Acceptance):

- **Off by default.** `converge.yml` runs this role only when
  `BOOTSTRAP_RETIRE=true` (with `BOOTSTRAP_USER` naming the account). Dev
  environments keep the provider door as a debug/break-glass path; prod
  retires it.
- **Ordered after proof of replacement access.** The role is invoked in
  converge `post_tasks`, after the `ansible` and `sysadmin` SSH+sudo
  validations have passed — never before.
- **Gate it on reboot validation.** Run `mise run vm:validate-reboot` first;
  retirement is the point of no return for the provider path (recovery
  afterwards is the provider console, not SSH).

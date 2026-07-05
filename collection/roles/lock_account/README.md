# account_lock role

Closes one account's login doors (RFC-005: Accounts and Access): strips its
`authorized_keys`, removes the cloud-init combined sudoers file
(`90-cloud-init-users`; the baseline accounts use their own per-user files),
removes `sudo`/`admin` group memberships, and locks the password. The
account is locked, never deleted: it still runs processes and owns files,
and a console can reverse the lock. Deletion is a human decision, outside
the collection.

Input: `account_lock_name` — the single account to lock. The role refuses
the baseline accounts by name. `cur8s.ubuntu.lock_accounts` is the intended
caller and loops it over `LOCK_ACCOUNTS`.

Safety model (RFC-005: Accounts and Access; RFC-004: Identity and Trust):

- **Never part of converge.** Converge asserts and never removes access
  (RFC-008: Convergence). Locking is a deliberate, standalone invocation:
  the playbook run is the consent — there is no enable toggle.
- **Ordered after proof of replacement access.** `cur8s.ubuntu.lock_accounts`
  validates `ansible` and `sysadmin` SSH+sudo before this role touches
  anything — never lock the old door before the new ones are proven.
- **Gate it on reboot validation.** Run the acceptance gate first
  (RFC-009: Validation and Acceptance); for a provider bootstrap door,
  recovery afterward is the provider console, not SSH.

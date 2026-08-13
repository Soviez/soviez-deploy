# Common Errors

Symbolic codes appear as `domain:CODE` in logs. Categories:

| Prefix | Domain |
|--------|--------|
| `SEC_*` / `SECURITY_*` / `PKG_*` | Security / apt lock |
| `UPDATE_*` | Updates |
| `OFFLINE_*` | Offline bundles |
| `BACKUP_*` / `RESTORE_*` | Backup/restore |
| `RETENTION_*` / Stage denial | Stage |
| `MIGRATION_*` | Migration |
| `OPERATION_*` | Ops engine |

Numeric exits 24/25 are shared across domains — always use the symbolic code.

Examples:

- `UPDATE_CAPABILITY_EXPIRED` — renew support/update entitlement; ERP still runs
- `STAGE_ENTITLEMENT_EXPIRED` — cannot create new Stages; existing remain
- `SEC_CRIT_*` — fail-closed containment; do not bypass
- `PKG_LOCK_*` — wait for apt

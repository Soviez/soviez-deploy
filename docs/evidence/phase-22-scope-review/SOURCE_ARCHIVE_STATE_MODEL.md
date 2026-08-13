# Source Archive State Model

```text
cutover_maintenance
→ rollback_window_closed
→ archive_preparing
→ archive_verified
→ runtime_suspended
→ retirement_ready
```

Do **not** use `purged` or `deleted` in Phase 22.

## `rollback_window_closed`

- Destination remains traffic owner
- Automatic rollback disabled
- Source retained; writes blocked; integrations disabled
- Rollback requires manual recovery plan

## `archive_preparing`

- Exact inventory captured; archive lock acquired
- Source unchanged; snapshot/dump created; **no deletion**

## `archive_verified`

- Checksums + DB + filestore + manifests valid
- Restore procedure validated per policy
- Source still retained

## `runtime_suspended`

- Stop ERP application / business cron / public Nginx site
- Keep database/filestore intact; preserve diagnostics, host access, backups
- PostgreSQL may stop **only after** archive verification (policy)
- No volume/host deletion

## `retirement_ready`

- Archive verified; destination stable; source non-public; runtime suspended
- Source License finalized; infrastructure inventory complete
- Purge remains unauthorized; Phase 23 readiness may be considered

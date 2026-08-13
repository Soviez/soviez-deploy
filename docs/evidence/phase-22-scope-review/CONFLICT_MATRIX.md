# Conflict Matrix

Conflicts with (block or serialize):

- Phase 21 rollback / recovery
- Another Phase 22 archive on same source
- Source write restoration
- Destination restore / backup (coordinate freshness)
- Source backup / source restore test
- Source or destination License mutation
- Source certificate renewal/revocation
- DNS change / source Nginx change
- Stage refresh/clone/delete
- Provider host stop/delete
- Backup retention deletion
- Credential rotation mid-archive
- Phase 23 purge/decommission
- Legal hold / owner hold / incident investigation

## Enforce

```text
one_active_archive_per_source
one_active_rollback_window_closure_per_cutover
one_active_source_license_finalization_per_license
one_active_runtime_suspend_per_source
```

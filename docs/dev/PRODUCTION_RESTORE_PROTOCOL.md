# Production Restore Protocol (Phase 16)

## CLI
```bash
sudo soviez.sh --restore <production-id> --backup <backup-id> [--confirm]
sudo soviez.sh --restore-status|cancel|retry|recover <operation-id>
sudo soviez.sh --restore-rollback <operation-id> [--confirm]
sudo soviez.sh --restore-cleanup <operation-id> [--confirm]
sudo soviez.sh --restore-test <backup-id>
sudo soviez.sh --restore-as-stage <backup-id> --stage-domain FQDN [--confirm]
```

## Flow (candidate-first)
1. Exact Production + exact backup IDs required
2. Compatibility: production_id, license_id, database_uuid, **same host**, Full type, preferably `VERIFIED`
3. Phase 14 conflict/lock for `production_restore`
4. Create isolated restore candidate (DB/filestore/runtime/network); neutralize outbound
5. Restore DB + filestore into candidate; validate
6. Confirm → switch Production → post-switch validate
7. On switch failure → rollback; Production preserved when candidate validation fails pre-switch

## Safety window
Default **24 hours** (`SOVIEZ_RESTORE_SAFETY_WINDOW_HOURS`) for rollback availability after successful restore.

## Denied
- Cross-host restore
- Database-only backups as Full restore source
- Unverified backups unless explicit allow env
- Wildcard / missing targets

## Op type
`production_restore` (+ related verify/restore-test ops). Integrates with unified operation engine cancel/retry/recover.

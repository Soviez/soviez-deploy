# Backup Consistency Protocol (Phase 16)

## Goal
Produce a restorable Full snapshot of one exact Production without copying live PostgreSQL data directories or sharing a writable filestore.

## Method
1. Target exact Production (no wildcards / Stage IDs as Production backup targets).
2. Database: `pg_dump -Fc` against the Production DB name (shared primitive with Stage live backup).
3. Filestore: archive a consistent tree copy/rsync snapshot into a compressed archive — never a live shared mount used by restore.
4. Record identity bindings: `production_id`, `license_id`, `database_uuid`, `host_identity`, ERP major.
5. Write scrubbed signed manifest; update inventory only after successful artifact materialization (or mark failed op terminal).

## Consistency notes
- Dump + filestore are taken in a defined backup op checkpoint sequence under Phase 14 locks/conflicts.
- Not crash-consistent WAL/PITR; Phase 16 is Full snapshot only.
- Database-only backups omit filestore and cannot feed Production Full restore.

## Failure
Partial dirs cleaned or left marked failed; never promote incomplete artifacts as `VERIFIED`.

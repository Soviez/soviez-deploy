# Phase 15 Recovery Set — Reuse Analysis

**Source:** `src/update/backup.sh` (+ rollback/candidate/engine)  
**Artifacts:** `recovery_set.json`, `rollback_manifest`, `checksums.txt`, db/filestore/config trees  
**Safety window:** 24h (update-scoped)

## What Phase 15 delivers

| Element | Behavior |
|---------|----------|
| Timing | Before candidate upgrade (`creating_backup` checkpoint) |
| DB | Copy path or fixture file — **not always** `pg_dump -Fc` |
| Filestore | Tree copy or marker |
| Integrity | SHA-256 style tree checksums; verify before proceed |
| Rollback | Candidate-first update rollback using recovery set |
| License Guard | Temporary update-candidate identity (`soviez.update-candidate-identity.v1`) |
| Product surface | Internal to `production_update` — **not** user backup CLI |

## Reuse for Phase 16 (recommended)

| Pattern | Reuse how |
|---------|-----------|
| Candidate-first | **Default restore path** — never overwrite Production by default |
| Manifest + checksums | Generalize into backup object model (`BACKUP_OBJECT_MODEL.md`) |
| Preflight capacity | Same discipline for backup/restore workspaces |
| Temporary LG identity | Same-host restore candidate reuses Phase 15 contract (see `LICENSE_GUARD_RESTORE_MODEL.md`) |
| Ops checkpoints | Mirror durable state machine under Phase 14 |
| Isolation of workspace | Restore candidate outside live Production paths |

## Do not reuse as-is

| Anti-pattern | Why |
|--------------|-----|
| Ship recovery_set as customer backup | Fixture/copy semantics; incomplete dump guarantee |
| 24h-only retention for Production backups | Update safety ≠ backup retention policy |
| Silent path-copy of live PG data dir | Prefer `pg_dump -Fc` for restore-capable Production units |
| Broaden update rollback into restore product without gates | Different confirmations, ownership, destinations |

## Boundary statement

Phase 15 recovery set remains **update-internal**.  
Phase 16 Production backup is a **separate product** that may share libraries and the candidate-first / LG temporary-identity patterns after authorized refactor.

## Refactor note (future implementation)

When authorized, extract shared:

- checksum / manifest writers  
- candidate workspace layout helpers  
- LG temporary identity binder  

Keep update-specific rollback_manifest schema and 24h cleanup under `src/update/`.

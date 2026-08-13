# Production Backup and Restore Model (Phase 16)

## Objective
Sovereign, ops-integrated **Production** Full backup and **candidate-first** same-host restore with verification, retention, optional owner-controlled remotes, and encryption — without Soviez-hosted backup and without weakening License Guard.

## Status
**PASS** — installer `0.16.0-phase16`. Progress **84%** (78 + 6). Closure evidence: `docs/evidence/phase-16-final-certification-closure/` (`FINAL_REPORT.md`). Implementation evidence retained: `docs/evidence/phase-16-production-backup-restore/`.

## Modules
- `src/backup/*` — object model, inventory, consistency, DB/filestore, encryption, destinations (local/S3/SFTP), retention, schedule, verify, restore-test, import/export, capacity, engine
- `src/restore/*` — targeting, compatibility, candidate, preflight, DB/filestore restore, switch, rollback, safety window, stage-restore, engine
- CLI: `--backup` / `--restore` and `--backup-*` / `--restore-*` family (see user docs)

## Backup unit (Full)
Default product unit: `pg_dump -Fc` + filestore archive + signed manifest (`soviez.backup.v1`).  
Database-only is advanced (`--type database-only --advanced`) and is **not** a Production restore source.

## Destinations
- **Local** required (primary)
- Optional owner remotes: **S3-compatible**, **SFTP** (`StrictHostKeyChecking=yes`)
- No Soviez SaaS / Soviez-hosted backup destination

## Encryption
- `openssl enc -aes-256-cbc -pbkdf2` (iter 100000); passphrase via env/file — never argv/logs
- Local: default **ON** (opt-out `SOVIEZ_BACKUP_DISABLE_ENCRYPTION=1` with warning)
- Remote (S3/SFTP): **mandatory**

## Retention / schedule
- Default classification keep: **7 daily / 4 weekly / 12 monthly**
- Pins protected from automated deletion
- Default schedule: **02:00 server-local**

## Restore
- Candidate-first (isolated DB/filestore/runtime/network); Production preserved until validated switch
- Same-host only — **cross-host restore denied** (`RESTORE_HOST_IDENTITY_MISMATCH`)
- Post-restore rollback **safety window: 24h** (`SOVIEZ_RESTORE_SAFETY_WINDOW_HOURS`)
- License Guard: temporary candidate identity; **no new permanent license slot**
- Optional `--restore-as-stage` (Stage entitlement rules apply)

## Shared Stage live backup
Stage live snapshots use `soviez_backup_stage_live_backup` with shared `pg_dump` primitives (closes Stage live-DB debt). Distinct from the Production backup product.

## Explicit exclusions
- No WAL / PITR / incremental backup product
- No cross-host restore (Phase 17 / migration)
- No backup payload upload to Soviez SaaS
- No Odoo web `/web/database/backup|restore` as the product path
- Phase 13 Stage retention archives and Phase 15 update recovery sets are **not** this product

## Sovereignty
Backup and restore are local/owner-destination operations. SaaS never receives dumps, filestore, backup archives, encryption keys, or destination credentials.

## Related
- User: `docs/user/BACKUP_AND_RESTORE.md`, `BACKUP_DESTINATIONS.md`, `BACKUP_RETENTION.md`, `RESTORE_AND_RECOVERY.md`
- Dev protocols under `docs/dev/BACKUP_*` and `PRODUCTION_RESTORE_*`
- Threat model: `docs/dev/BACKUP_SECURITY_THREAT_MODEL.md`

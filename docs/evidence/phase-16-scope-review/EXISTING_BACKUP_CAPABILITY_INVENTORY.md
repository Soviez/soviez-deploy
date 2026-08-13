# Existing Backup Capability Inventory

**Scope:** Read-only facts for Phase 16 correction. English product copy only.

## Summary table

| # | Capability | Owning phase | Restore? | Production product? | Notes |
|---|------------|--------------|----------|---------------------|-------|
| 1 | Stage create snapshot | 11 | PG restore into **new Stage** only | No | Real `pg_dump -Fc` / `pg_restore`; UUID rotate |
| 2 | `--stage-backup` | 11 | **No** | No | Identity + filestore tar; live DB dump **only** in `SOVIEZ_TEST_MODE` |
| 3 | Retention final backup | 13 | **No** product restore | No | Delegates to stage backup → inherits DB gap |
| 4 | Ops restore/backup slots | 14 | Reserved | No | Conflict/adapters only |
| 5 | Update recovery set | 15 | Update rollback only | No | Path/fixture copy; not always `pg_dump -Fc` |
| 6 | Legacy `--backup` | legacy deploy | **No** | Yes (legacy) | Real `pg_dump -Fc` + filestore; 5GB buffer |
| 7 | Odoo web DB backup/restore | ERP | Yes (web) | **Exclude** | Master-password web path — unsafe for Phase 16 |
| 8 | Scheduled Production backup | — | — | **Missing** | Not in installer |
| 9 | Remote S3 / encryption | — | — | **Missing** | Not in installer |
| 10 | SaaS offline Stage package | SaaS | N/A | No | Auth ticket only — not data backup |

## 1. Phase 11 — Stage create snapshot

**Files:** `src/stage/snapshot.sh`, `src/stage/clone.sh`, `src/stage/pg.sh`  
**Functions:** snapshot helpers; `soviez_stage_pg_dump_fc`; restore into Stage clone path.

| Property | Value |
|----------|-------|
| Direction | Production → Stage only |
| DB method | Real `pg_dump -Fc` (docker exec or local) |
| Filestore | Copy into Stage paths |
| UUID | Rotated for Stage isolation |
| Reuse | Strong primitives for Phase 16 dump/restore plumbing |
| Product CLI | Stage create — **not** `--backup` / `--restore` |

## 2. Phase 11 — `--stage-backup`

**File:** `src/stage/lifecycle.sh` — `soviez_stage_cmd_backup`  
**CLI:** `soviez.sh --stage-backup <stage-id>`

| Property | Value |
|----------|-------|
| Contents (live) | Stage identity JSON + filestore tree tar |
| DB (live) | **Not dumped** unless `SOVIEZ_TEST_MODE=1` fixture dir copy |
| Checksum | SHA-256 of archive |
| Destination | `/var/soviez/backups/stages/` |
| Restore | **None** |
| Risk | Unsafe if treated as full restore-capable backup |

**Verdict:** Needs refactor before any Stage “full backup” claim; must not be the Production backup product.

## 3. Phase 13 — Retention final backup

**File:** `src/stage/retention_engine.sh` — `soviez_retention_final_backup`  
**Flow:** Calls `soviez_stage_cmd_backup` → archives under `/var/soviez/backups/retention/` + sha256 + retention metadata.

| Property | Value |
|----------|-------|
| Integration | Ops-integrated retention delete path |
| DB gap | **Inherited** from stage backup |
| Restore product | **None** |
| Relation to Phase 16 | Ops pattern + archive layout lessons; not Production backup |

## 4. Phase 14 — Operation engine reserves

**Files:** `src/ops/conflicts.sh`, `src/ops/adapters.sh`  
**Behavior:** Conflict rules mention `stage_backup`, `restore`, `update`; adapter checkpoints reserve future restore/backup slots.

| Property | Value |
|----------|-------|
| Data backup product | **None** |
| Value for Phase 16 | Conflict matrix + op types must extend here |

## 5. Phase 15 — Update recovery set

**File:** `src/update/backup.sh`  
**Artifacts:** `recovery_set.json`, `rollback_manifest`, checksums, 24h safety window.

| Property | Value |
|----------|-------|
| DB method | Path/fixture **copy**; not guaranteed `pg_dump -Fc` |
| Purpose | Candidate-first update rollback |
| User backup product | **No** (internal) |
| Reuse for Phase 16 | Candidate-first pattern, manifests, checksum verify, LG temporary identity |

## 6. Legacy soviez-deploy

**File:** `/Volumes/PortableSSD/soviez-project/soviez-deploy/soviez.sh`  
**CLI:** `--backup <tenant> <db>`, `--backup-list`

| Property | Value |
|----------|-------|
| DB | Real `pg_dump -Fc` |
| Filestore | tar.gz |
| Destination | `/var/soviez/backups` |
| Space check | 5GB host buffer |
| Restore | **None** |
| Ops engine | **None** |
| Encryption | **None** |

## 7. Soviez ERP Odoo web path

**Paths:** `/web/database/backup`, `/web/database/restore` (master password).  
**Phase 16 stance:** **Exclude** from product. Unsafe web master-pwd surface; not installer-owned.

## 8–10. Explicit gaps

- No scheduled Production backup in soviez-sh  
- No remote S3-compatible destination in installer  
- No backup encryption in installer  
- SaaS offline Stage package = authorization ticket, **not** DB/filestore backup  
- Old master plan “Keep backup; add restore” is false for soviez-sh: **no** `--backup` / `--restore` CLI exists today  

## CLI reality check (soviez-sh)

Present: `--stage-backup` (Stage only).  
Absent: `--backup`, `--restore`, `--backup-list` (Production product).

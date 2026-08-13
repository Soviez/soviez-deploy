# Phase 13 Stage Backup — Reuse Analysis

**Source:** `src/stage/retention_engine.sh` → `soviez_retention_final_backup`  
**Delegate:** `soviez_stage_cmd_backup` (`src/stage/lifecycle.sh`)  
**Layout:** `/var/soviez/backups/retention/<stage-id>/…` + `.sha256` + `retention.json`

## What Phase 13 delivers

| Element | Behavior |
|---------|----------|
| Trigger | Before Safe Shield Stage deletion |
| Archive | Copies stage backup tar + checksum into retention tree |
| Ops | `retention_delete` / `final_backup_running` states |
| Restore | **No** installer restore product |
| Independence | Retention clock independent of Stage License (D086–D088) |

## Critical inherited gap

`soviez_stage_cmd_backup` on live hosts archives **identity + filestore** only.  
Live DB dump occurs **only** when `SOVIEZ_TEST_MODE=1` and a fixture DB directory exists.

Therefore retention “final backup” is **not** a restore-capable full Stage snapshot on production hosts today.

## Reuse for Phase 16

| Useful | How |
|--------|-----|
| Ops-integrated backup step before destructive work | Same idea for Production restore switch / retention cleanup |
| SHA-256 sidecar + metadata JSON | Align with backup object model |
| Needs Action on ambiguity | Failure taxonomy for backup/restore |
| Independence principle | Production backup retention **independent** of Stage 14–60 day policy |

## Do not reuse

| Anti-pattern | Why |
|--------------|-----|
| Call stage backup for Production | Wrong target class |
| Claim Phase 13 archives are Production backups | Different environment, incomplete DB |
| Tie Production retention to Stage 14–60 | Explicitly independent (owner decision OD-04) |

## Required Stage-side refactor (adjacent debt)

Phase 16 Production product does **not** unblock until Stage backup is honest — but Stage fix may be a **separate** authorized task:

1. Live Stage backup must `pg_dump -Fc` (reuse `soviez_stage_pg_dump_fc`).  
2. Document restore-or-not for Stage archives.  
3. Retention final backup then inherits a real dump.

Until then: label Stage/retention archives accurately in operator messaging (English).

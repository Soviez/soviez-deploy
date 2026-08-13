# PHASE_16_OVERLAP_REVIEW.md

**Date:** 2026-08-02  
**Peer:** Phase 16 — Production Backup, Restore, Verification, and Recovery

## What Phase 16 owns (keep)

- Full backup object: `pg_dump -Fc` + filestore archive + signed/HMAC manifest  
- VERIFIED / RESTORE_TESTED states; age and pin semantics for recovery units  
- Local/same-host restore and switch patterns; SFTP/S3 off-host **backup** destinations  
- Stage live backup sharing dump helpers  

## What Phase 19 reuses

- Final DB consistency unit: Phase 16 `-Fc` dump during short write freeze (Option B)  
- Checksum/manifest discipline → transfer manifest (`TRANSFER_MANIFEST_MODEL.md`)  
- Filestore archive tools as **secondary** packaging; primary migrate = file-level chunked pre-sync  
- Pre-migration backup policy pins a source Full through Phases 19–21 (`PRE_MIGRATION_BACKUP_POLICY.md`)  

## What Phase 19 must not duplicate or misuse

| Anti-pattern | Why |
|--------------|-----|
| Treating SFTP/S3 Full archive upload as “migration” | Wrong plane; not resumable peer stream |
| Same-host restore switch on destination | Activates Production; Phase 19 is staging only |
| WAL/PITR continuous replication | Explicitly out of Phase 19 (Option B) |
| Second dump engine beside Phase 16 helpers | Share `pg_dump_fc` / restore helpers |

## Boundary

Phase 16 = **backup/restore product**. Phase 19 = **cross-host streaming transfer + dest staging**. Backup remains a **gate/prerequisite**, not the transfer protocol.

# Conflict Matrix — Phase 16 (Proposed)

**Principle:** Exact environment/resource locks. Avoid host-wide lock unless justified and documented.

Legend:

| Symbol | Meaning |
|--------|---------|
| **deny** | Refuse to start the incoming op |
| **wait** | Queue / `retry_scheduled` until active finishes or safe window |
| **allow** | May coexist (different env/resources) |
| **serial** | Same lock key; second waits or denies per policy |

## Actors considered

Production update · update image cleanup · migration · Stage clone/refresh · Stage deletion / retention · SSL cutover · domain changes · manual backup · scheduled backup · restore · restore-test · rollback · retention cleanup · offline import/export · License activation · database mutation · filestore mutation

## Core matrix (same Production unless noted)

| Active \ Incoming | production_backup | production_restore | production_update | stage_create/refresh | retention_delete | ssl_cutover / domain | backup_cleanup | migrate |
|-------------------|-------------------|--------------------|-------------------|----------------------|------------------|----------------------|----------------|---------|
| production_backup | **deny** duplicate | **deny** | **wait** (deny near switch) | **wait** if quiescing source | **allow** other Stage | **wait** | **deny** same `backup_id` | **deny** |
| production_restore | **deny** | **deny** | **deny** | **deny** same parent | **deny** related Stage | **deny** | **deny** same backup | **deny** |
| production_update | **wait** | **deny** | **deny** | per Phase 15 | per existing | **deny** during cutover | **allow** unrelated backups | **deny** |
| backup_restore_test | **allow** if disk OK | **deny** exclusive backup | **allow** careful | **allow** | **allow** | **allow** | **deny** same backup | **deny** |
| scheduled backup | **deny** duplicate Production | **deny** | **wait** | **allow** other | **allow** | **wait** | **wait** | **deny** |
| backup_export/import | **wait** if writing same id | **deny** if restore holds id | **allow** | **allow** | **allow** | **allow** | **deny** deleting export source | **deny** import during migrate |
| License activation | **serial** on License id if overlapping | **deny** during candidate validate/switch | per Phase 8/15 | per Stage rules | **allow** | **allow** | **allow** | **deny** |

## Narrative rules

1. Backup may coexist with read-only observation; not with restore or update **switch** on the same Production.  
2. Restore conflicts with update and migration on the same Production (hard **deny**).  
3. Retention cleanup conflicts with any op holding the same `backup_id` (restore, restore-test, export).  
4. Scheduled backup must not duplicate a running backup for the same Production.  
5. Stage clone/refresh from Production should **wait** if Production is mid-quiesce backup or restore switch.  
6. SSL cutover / domain promotion **denies** concurrent restore switch; may **wait** backup.  
7. Update image cleanup must not delete images required by an in-flight restore candidate (reuse Phase 15 image protection spirit).  
8. Offline Stage package import/export is **not** Production backup; still serialize if it mutates shared host paths.  
9. External DB/filestore mutation tools outside the installer cannot be perfectly locked — document operator discipline; installer fails closed when it detects obvious concurrent dumps if feasible.  
10. Avoid a global host lock; prefer `production_id` + `backup_id` + License id lock keys.

## Existing code touchpoints

`src/ops/conflicts.sh` already encodes update↔restore and stage_backup↔retention pairs. Phase 16 must extend with Production backup/restore types without weakening those denies.

`src/ops/adapters.sh` reserves restore/backup-oriented checkpoints — fill with real adapters only after implementation authorization.

## Failure if violated

Starting a conflicting op must return a stable English error with the blocking `operation_id`, never partially quiesce Production then abandon locks.

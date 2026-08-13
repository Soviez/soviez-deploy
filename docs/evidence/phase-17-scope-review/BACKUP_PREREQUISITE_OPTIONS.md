# Backup Prerequisite Options — Phase 17

**No live backup is created during this scope review.**

## Options

| Option | Discovery | Readiness PASS | Transfer authorize (later) |
|--------|-----------|----------------|----------------------------|
| A | No new backup required | Backup **capability** healthy | Recent verified Full **or** new pre-migration backup |
| B | No new backup | Require recent verified Full for PASS | Same |
| C | Force new backup during discovery | Always fresh | Always fresh |

## Recommendation

**Option A (recommended for owner confirmation as OD-01/OD-02):**

- Discovery may run without creating a new backup.  
- Readiness **PASS** requires backup capability healthy (schedule/engine/encryption/destinations as applicable).  
- Transfer authorization (Phase 19+) requires a recent verified Full backup **or** a new pre-migration backup.  
- Exact age threshold = **owner decision** (OD-02).  

## Codes

`MIGRATION_BACKUP_PREREQUISITE_MISSING` when policy requires backup and it is absent/unhealthy.

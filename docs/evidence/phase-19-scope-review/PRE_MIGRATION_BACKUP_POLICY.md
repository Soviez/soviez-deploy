# PRE_MIGRATION_BACKUP_POLICY.md

**Date:** 2026-08-02  
**Depends on:** Phase 16 Full backup object model

## Gate at final pass start

| Requirement | Default recommendation | Status |
|-------------|------------------------|--------|
| Exact **source** Full backup | Mandatory | Owner-pending (OD-06) |
| State **VERIFIED** | Mandatory | Owner-pending |
| Age ≤ **24h** at final pass start | Mandatory | Owner-pending |
| **RESTORE_TESTED** | Recommended, **not** mandatory | Owner-pending (OD-07) |
| Pin backup ID through Phases **19–21** | Yes | Owner-pending (OD-08) |

## Role of backup vs transfer

- Backup = **rollback/prerequisite safety net** on source (and off-box if configured)  
- Transfer = **direct peer stream** to destination staging  
- SFTP/S3 destinations remain backup planes, not migrate planes  

## On failure of gate

- Final pass **BLOCKED** until a fresh VERIFIED Full within age window exists  
- Pre-sync may proceed with WARNING if OD allows; final apply must not  

## Destructive note

Creating a new Full backup is write-I/O heavy but non-destructive to business data. Mark owner-pending where policy forces backup before every retry.

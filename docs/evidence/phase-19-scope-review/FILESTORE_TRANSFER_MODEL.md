# FILESTORE_TRANSFER_MODEL.md

**Date:** 2026-08-02

## Primary approach

**File-level chunked filestore pre-sync** (multi-pass) + final-pass delta under write freeze.

| Aspect | Default |
|--------|---------|
| Unit | Individual filestore files / object paths |
| Transport | mTLS chunks (64 MiB fixed) |
| Integrity | Per-file digest in transfer manifest |
| Archive tar.zst | Optional packaging aid; **not** required as sole migrate blob |

## Why not only Phase 16 tar as stream

- Large single archive hurts resume granularity  
- Pre-sync benefits from file-level skip-if-unchanged  

## Staging apply

- Write into destination staging filestore volume  
- No public ERP serving of staging filestore  
- Capacity checks before each major pass (`CAPACITY_MODEL.md`)  

## Deletes / renames

- Final pass reconciles tombstones/renames observed under freeze window policy (document exact algorithm at impl)  
- Abort default **preserves** staging data (`CANCELLATION_AND_ABORT_MODEL.md`)

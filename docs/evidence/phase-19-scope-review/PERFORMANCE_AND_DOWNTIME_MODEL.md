# PERFORMANCE_AND_DOWNTIME_MODEL.md

**Date:** 2026-08-02

## Downtime definition (Phase 19)

Only **app write freeze** window counts as write-downtime. Source may remain readable depending on app semantics. ERP stop / PG stop are **not** default.

| Metric | Target |
|--------|--------|
| Final write-freeze max | **15 minutes** |
| Hard timeout | Yes; **auto release** |
| Pre-sync | Online; no freeze |

## Performance levers

- Chunk size 64 MiB; zstd balanced; bandwidth balanced  
- File-level skip-unchanged on later pre-sync passes  
- DB dump only on final pass  

## Reporting

Transfer op exposes: bytes/sec, ETA, freeze countdown, remaining chunks. Exceeding freeze budget → abort final attempt path per state machine — do not silently extend without OD.

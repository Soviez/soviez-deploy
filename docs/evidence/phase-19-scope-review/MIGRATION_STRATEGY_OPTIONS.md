# MIGRATION_STRATEGY_OPTIONS.md

**Date:** 2026-08-02  
**Recommendation:** **Option B** (owner approval required — OD-01)

## Option A — Single freeze + one-shot transfer

- Long write freeze covering full DB+filestore copy  
- Simpler state machine; poor downtime for large filestores  
- **Not recommended** as default

## Option B — Multi-pass pre-sync + short final write freeze (**recommended**)

| Pass | Behavior |
|------|----------|
| Pre-sync N | Live source; chunked filestore + non-destructive inventory; optional Stage payloads |
| Final pass | App **write freeze** (hard timeout; auto release); Phase 16 `-Fc` dump for DB; filestore delta; apply to dest staging |
| Post | Source **ACTIVE**; staging validated; Ready-for-20 report |

Constraints:

- **No WAL/PITR** in Phase 19  
- Final write-freeze **max target 15 minutes**; hard timeout; auto release  
- App write freeze ≠ ERP stop ≠ PG stop ≠ maintenance landing  

## Option C — Continuous logical replication / WAL shipping

- Near-zero cutover later; high ops/complexity; new failure domains  
- **Out of Phase 19** (defer unless separate OD expands scope)

## Option D — Cloud archive relay (Full → SFTP/S3 → dest)

- Reuses Phase 16 destinations as “transport”  
- **Unsafe as primary** (see inventory); allowed only as disaster off-box backup prerequisite, not migrate stream  

## Selection matrix (summary)

| Criterion | A | B | C | D |
|-----------|---|---|---|---|
| Downtime control | Poor | Good | Best* | Medium |
| Resume | Hard | First-class | Complex | Archive-level |
| Reuse Phase 16 `-Fc` | Yes | Yes (final) | No | Yes |
| Phase 19 fit | Weak | **Strong** | Over-scope | Wrong plane |

\*Best only if fully engineered; not authorized here.

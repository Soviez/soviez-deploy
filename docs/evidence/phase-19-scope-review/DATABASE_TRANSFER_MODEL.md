# DATABASE_TRANSFER_MODEL.md

**Date:** 2026-08-02  
**Strategy:** Option B — **no WAL/PITR**

## Final DB unit

Reuse Phase 16 **`pg_dump -Fc`** under short app write freeze; transfer dump artifact via chunked mTLS; apply with Phase 16 **`restore_fc`** patterns into **destination staging** DB (not Production switch).

## Pre-sync

- DB pre-sync optional/limited (dump is heavy); prefer filestore multi-pass; DB = **final pass primary**  
- Do not run continuous logical replication in Phase 19  

## Apply rules

| Rule | Value |
|------|-------|
| Target | Isolated staging cluster/db name |
| Same-host Production switch | **Forbidden** |
| Cross-host allowlist | Required (missing today — see inventory) |
| Static gates | Scoped update to allow dump/restore **only** in authorized transfer modules |

## Consistency

Final dump under freeze = consistency point for Ready-for-20 DB criterion. Post-freeze source writes are **not** mirrored until a future phase expands scope.

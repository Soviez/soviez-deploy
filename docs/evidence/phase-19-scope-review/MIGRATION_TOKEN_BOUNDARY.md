# MIGRATION_TOKEN_BOUNDARY.md

**Date:** 2026-08-02  
**Continuity:** Phase 17 token boundary unchanged in Phase 19

## Allowed

- Eligibility check only (token exists / not expired / suitable for future migrate)  
- Surface eligibility on Ready-for-20 report  

## Forbidden in Phase 19

| Action | Phase |
|--------|-------|
| Soft-reserve / hard-reserve | 20+ |
| Consume / burn / HMAC migrate receipt | 20 |
| `reserved=true` or `consumed=true` persistence | 20 |
| Second token purchase forced by transfer | never as side effect |

## Invariants

```text
reserved = false
consumed = false
```

throughout all transfer states including Abort and reboot recovery.

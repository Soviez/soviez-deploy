# DESTINATION_STAGING_MODEL.md

**Date:** 2026-08-02

## Identity

Isolated **non-Production** staging identity on destination host (analogy: Phase 15 update-candidate — apply without switch).

| Property | Default |
|----------|---------|
| Production slot bind | **No** |
| Public login / ERP UI exposure | **No** |
| Internal technical validation | **Allowed** (ops/CLI health, DB checks) |
| Landing (Phase 18) | May coexist on mig FQDN; ≠ staging ERP public |
| Network | Prefer private/admin paths for validation |

## Apply surface

- Cross-host apply allowlist (missing — to implement)  
- Restore DB/filestore/addons into staging paths only  
- No nginx cutover of Production domain to staging ERP  

## Lifecycle

- Created/updated by transfer ops  
- Abort **preserves** staging by default; optional exact-delete  
- Promotion to Production = Phase **21** (out of scope)  

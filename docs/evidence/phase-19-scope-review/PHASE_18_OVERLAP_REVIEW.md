# PHASE_18_OVERLAP_REVIEW.md

**Date:** 2026-08-02  
**Peer:** Phase 18 — Maintenance Landing, Signed Domain Validation, and Migration Routing Readiness

## What Phase 18 owns (keep)

- Migration domain plan; signed DNS challenge; mig-subdomain TLS  
- Neutral maintenance landing on destination mig FQDN  
- Routing readiness report (PASS/WARNING/BLOCKED)  
- Source traffic **unchanged**; no Production cutover  
- Abort preserves owner DNS  

## What Phase 19 consumes as inputs

- Routing readiness **PASS** (or owner-accepted WARNING set) within validity window  
- Pair-bound domain/TLS/landing artifacts as **eligibility** for starting transfer  
- Conflict matrix awareness: concurrent `domain_*` vs `migration_transfer_*`  

## What Phase 19 must not do

| Action | Owner phase |
|--------|-------------|
| Production DNS/traffic cutover | 21 |
| Source Production maintenance page enable for cutover | 21 |
| Mig-subdomain → Production ERP public login | 21 |
| Token reserve/consume | 20 |
| Treat landing as ERP | never in 19 |

## Continuity

- Maintenance landing may remain up during transfer; **≠** app write freeze ≠ ERP stop ≠ PG stop  
- Phase 19 destination staging is **internal/isolated**; public login remains blocked  

## Boundary

Phase 18 = **routing control plane readiness**. Phase 19 = **payload transfer + private staging**. Routing readiness is prerequisite, not transfer.

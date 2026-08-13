# PHASE_18_OVERLAP_REVIEW.md

**Date:** 2026-08-03  
**Peer:** Phase 18 — Maintenance Landing, Signed Domain Validation, and Migration Routing Readiness

## What Phase 18 owns (keep)

- Migration domain plan bound to exact Phase 17 pair.
- Signed DNS challenge (TXT) + observation/validation for **ownership proof**.
- Pre-cutover TLS on **migration subdomain** (`migrate.<production-domain>`).
- Neutral maintenance landing on mig FQDN (not Production ERP).
- Routing readiness report with `cutover_authorized: false`.
- Manual/offline DNS instruction path (provider-neutral text output).
- Source Production traffic **unchanged** throughout Phase 18.

## What Phase 21 reuses directly

| Phase 18 artifact | Phase 21 use |
|-------------------|--------------|
| Domain plan + production FQDN | Target for Production DNS switch instructions |
| DNS challenge proof | Prerequisite; does not replace authoritative A/AAAA/CNAME cutover |
| Routing plan JSON | Input to destination nginx Production route activation |
| Nginx ownership markers (mig site) | Pattern for Production site ownership on destination |
| SSL challenge/inventory/promote | Production cert issuance on destination host |
| Manual DNS renderer | **First-class** for Production record change (no fixture-only for live) |
| Readiness PASS/WARNING/BLOCKED | Superseded by Phase 21 readiness after cutover steps |

## What Phase 21 must not assume from Phase 18

| Assumption | Reality |
|------------|---------|
| Mig-subdomain TLS = Production TLS | Production cert must be validated separately on destination |
| Landing preview = ERP health | Public health gate runs against Production domain post-DNS |
| Routing plan ready = cutover authorized | `cutover_authorized` flips only in Phase 21 after owner gates |
| DNS challenge = DNS cutover | Challenge proves control; authoritative switch is separate manual step |

## Boundary

Phase 18 = **control-plane readiness** (plan, proof, mig landing, routing blueprint).  
Phase 21 = **Production traffic ownership transfer** (dest route, DNS, TLS, health, traffic_owner).

## Continuity rule

Phase 18 mig landing may remain during Phase 19–20. Phase 21 may retire mig landing after Production route is healthy, or keep it as rollback pointer per owner policy (OD-12).

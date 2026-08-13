# DOMAIN_ROUTING_BOUNDARY.md

**Date:** 2026-08-02  
**Continuity:** Phase 18 destination routing boundary

## Inputs from Phase 18

- Routing readiness report within validity  
- Mig-subdomain TLS + landing present as required by readiness  
- Pair-bound domain plan  

## Phase 19 must not

| Action | Phase |
|--------|-------|
| Production DNS cutover | 21 |
| Lower Production TTL as side effect | 18 OD already default No; still not 19 |
| Replace landing with ERP on public Production hostname | 21 |
| Mutate owner DNS beyond what 18 already did | never ad hoc |
| Start transfer if routing readiness BLOCKED | gate |

## Source traffic

Source Production routing remains authoritative for users throughout Phase 19.

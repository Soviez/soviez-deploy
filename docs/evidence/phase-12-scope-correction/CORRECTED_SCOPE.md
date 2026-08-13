# CORRECTED_SCOPE.md

## Title

**Phase 12 — Domain/SSL Lifecycle Hardening, Renewal, Recovery, and Production Policy**

## Objective

Post-provision certificate and DNS/Nginx operational lifecycle and hardening; Production policy only after separate owner authorization. Does **not** reimplement Phase 11 initial Stage domain/SSL provisioning.

## In scope

### Certificate lifecycle
- Expiry monitoring; configurable renewal window  
- Renewal attempt state, retry, backoff  
- Certificate replacement; old certificate rollback  
- Chain verification; hostname verification  
- Private-key permission validation  
- Certificate metadata inventory  

### DNS challenge lifecycle
- Signed challenge verification  
- Finite DNS propagation waiting  
- Try Again; Abort Safely; resume after interruption  
- Stale challenge detection  
- Exact-domain and exact-host binding  
- Replay protection  
- No automatic DNS-provider mutation  

### Nginx ownership and recovery
- Clearly owned generated config  
- No overwrite of unrelated host config  
- `nginx -t` before reload  
- Atomic config promotion where possible  
- Rollback on failed validation  
- Safe reload; no global restart unless required and documented  
- Collision detection; orphaned config reconciliation  
- Stage-specific and Production-specific ownership  

### Repair and diagnostics
- Local status: certificate, DNS, Nginx, expiry, renewal  
- Repair command; reattach/recovery where operation engine supports it  
- No mandatory SaaS request for local health checks  

### Production policy (owner-gated)
- Whether Production requires mandatory domain and trusted SSL  
- Whether installation may remain incomplete until Production HTTPS passes  
- Whether trusted private CA is allowed outside isolated tests  
- Whether temporary HTTP is permitted during initial provisioning  
- Whether renewal failure blocks only acceptance or affects runtime  
- Whether Production policy differs from Stage policy  

**Unresolved questions must not be decided silently** — see `OWNER_DECISIONS_REQUIRED.md`.

## Explicit non-goals

- Reimplement initial Stage domain collection or uniqueness  
- Reimplement initial trusted TLS issuance  
- Reimplement self-signed rejection already certified  
- Reimplement Phase 11 Stage creation  
- Stage entitlement logic  
- Stage Operation Ticket redesign  
- Stage neutralization  
- Stage-origin certificate redesign  
- Stage retention  
- `--update`  
- Backup/restore redesign  
- Migration  
- Automatic DNS-provider mutation  
- Live deployment  
- Changing SaaS commercial behavior  

## Complexity / weight

- Complexity: **Medium-High** (unchanged class)  
- Proposed weight: **4** — documented only; **not applied**; no progress credit  

## Authorization

**IMPLEMENTATION NOT AUTHORIZED** until owner approves this scope and answers required decisions.

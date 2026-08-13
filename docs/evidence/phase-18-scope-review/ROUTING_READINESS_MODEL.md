# ROUTING_READINESS_MODEL.md

## Routing-plan object (no cutover)

Fields (minimum):

- `migration_pair_id`, `plan_id`, `status`, `issued_at`, `expires_at`, signature  
- `source_domain`, current A/AAAA/CNAME (observed), source endpoint  
- `migration_fqdn`, destination migration endpoint, future Production endpoint (**planned only**)  
- current source certificate summary; migration-subdomain certificate summary  
- Nginx config references (landing site id)  
- health endpoints  
- planned maintenance route; planned ERP route (**disabled template optional** OD-31)  
- rollback route notes  
- DNS TTL state; expected propagation window  
- owner approvals; cutover prerequisites; Phase 19/20/21 dependency flags  
- source retention behavior (informational)  
- failure codes  

## PASS / WARNING / BLOCKED (recommended)

| Result | Conditions |
|--------|------------|
| PASS | Pair valid; challenge verified; landing healthy; mig TLS valid; source unchanged; fingerprints match |
| WARNING | Propagation slow but eventually ok; IPv6 broken while IPv4 ok; cert lead-time short |
| BLOCKED | Pair expired/revoked; source drift; landing/TLS fail; challenge invalid; token somehow reserved (should be impossible) |

Validity: **24h** or immediate invalidation on material drift (pair revoke, source DNS change, dest identity change, landing/TLS change).

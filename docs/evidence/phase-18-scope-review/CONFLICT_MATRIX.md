# CONFLICT_MATRIX.md

Exact locks only. **No global DNS lock.**

| Active \ Incoming | domain_plan | dns_challenge/validation | landing | tls_prepare | routing_readiness | Phase 12 SSL renew same host | Phase 19 transfer | Phase 20/21 | update/restore switch | pair expired/revoked |
|-------------------|-------------|--------------------------|---------|-------------|-------------------|------------------------------|-------------------|-------------|----------------------|----------------------|
| domain_plan same pair | deny | wait | wait | deny | deny | allow other hosts | deny | deny | deny | abort |
| dns_challenge same FQDN | wait | deny duplicate | wait | wait until verified | deny | deny if same FQDN | deny | deny | deny | abort |
| landing same site | wait | allow try-again | deny | wait | wait | allow unrelated | deny | deny | deny | abort |
| tls_prepare same FQDN | deny | deny | wait | deny duplicate ACME | wait | **deny** | deny | deny | deny | abort |
| routing_readiness | allow refresh | allow | allow | allow | deny concurrent write | allow | deny | deny | deny | abort |
| source domain mutation detected | BLOCK | BLOCK | BLOCK | BLOCK | BLOCK | — | — | — | — | — |
| bootstrap/pair expiry | deny all new | — | — | — | — | — | — | — | — | — |

Read-only source domain inspection may coexist with normal Production runtime.

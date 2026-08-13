# Migration Domain and Routing Readiness Model

Phase 18 prepares the **domain, DNS ownership, maintenance landing, migration-subdomain TLS, and routing-plan** control plane bound to an exact Phase 17 migration pair — **without** payload transfer, Production cutover, Migration Token consume, or destination Production activation.

**Status:** PASS (2026-08-02). Progress **93%** (89+4). Installer `0.18.0-phase18`. Evidence: `docs/evidence/phase-18-migration-domain-routing/`.

## Modules

`src/migration/{domain,dns,landing,tls,routing,commands}/` (plus Phase 17 common/discovery/bootstrap/pairing/readiness)

## Defaults

| Setting | Value |
|---------|-------|
| Domain strategy | `migrate.<production-domain>` |
| Ownership TXT | `_soviez-migration.<migration-fqdn>` |
| DNS challenge TTL | 30 minutes (`SOVIEZ_MIG_DNS_CHALLENGE_TTL_SECONDS=1800`) |
| Recommended DNS record TTL | 300 seconds |
| Routing readiness TTL | 24 hours |
| DNS validation | Authoritative + ≥2 public resolvers must agree |
| Landing | Temporary nginx site on migration FQDN only |
| TLS | Public CA on mig FQDN (LE / Pebble fixture); no Production-domain pre-issue |
| Abort | Remove destination landing/TLS/challenge state; **preserve owner DNS** |

## Binding outcome

```text
MIGRATION PAIR — VALID
DOMAIN PLAN — COMPLETE
DNS CHALLENGE — VERIFIED
DESTINATION LANDING — READY
TLS — VALID
ROUTING PLAN — READY
SOURCE TRAFFIC — UNCHANGED
NO BUSINESS DATA TRANSFERRED
MIGRATION TOKEN — NOT RESERVED / NOT CONSUMED
DESTINATION ERP PRODUCTION — NOT ACTIVATED
```

## Boundaries

| Later phase | Owns |
|-------------|------|
| 19 | Streaming payload transfer |
| 20 | Token burn / License rebind |
| 21 | Production traffic cutover / source maintenance on Production domain |
| 22 | Source purge |

Phase 19 remains **UNAUTHORIZED**.

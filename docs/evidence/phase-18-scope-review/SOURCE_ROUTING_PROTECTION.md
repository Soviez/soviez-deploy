# SOURCE_ROUTING_PROTECTION.md

## Hard bans (static + runtime gates)

Phase 18 code paths must refuse:

- Source Nginx mutation / reload for Production site  
- Source ERP stop / container stop  
- Source maintenance enablement (cutover maintenance)  
- Source domain A/AAAA/CNAME replacement  
- Source certificate removal or Production cert promote for cutover  
- Source firewall route removal  
- Source License mutation  
- Production-domain TTL lowering by default (OD-32 deny)  

## Allowed

Read-only inspection: resolve DNS, read nginx conf checksums, cert notAfter, HTTP health of source `/web/login`.

## Drift detection

Compare fingerprints from Phase 17 discovery + fresh observation; on mismatch → `MIGRATION_SOURCE_ROUTING_CHANGED` / `MIGRATION_SOURCE_DISRUPTION_DETECTED` → BLOCKED readiness.

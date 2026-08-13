# DNS_PROVIDER_MODEL.md

## Mandatory path

**Manual DNS instructions** are first-class: show exact record name/type/value/TTL; offline printable package; Try Again after owner update.

## Optional path

Provider-neutral **local** adapter contract:

- Credentials stay on destination/source admin host — **never** SaaS  
- Explicit owner confirmation before any write  
- Exact-record create/update/delete only for migration FQDN records Phase 18 owns  
- No Production apex mutation in Phase 18  

## Phase 18 inclusion recommendation

| Item | Recommendation |
|------|----------------|
| Manual DNS | **In scope / mandatory** |
| Provider adapters | **Deferred or stub contract only** unless owner OD-12 says include |
| Initial providers | None required; if included later: Cloudflare/Route53-class via local tokens |

## Risks of early automation

Accidental Production-record mutation; credential exfil; SaaS temptation to store tokens — **forbidden**.

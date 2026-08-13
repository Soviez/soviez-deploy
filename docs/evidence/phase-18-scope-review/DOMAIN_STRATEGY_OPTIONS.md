# DOMAIN_STRATEGY_OPTIONS.md

## Option A — Dedicated temporary migration subdomain (recommended default)

Example: `migrate.example.com` (or owner-chosen equivalent).

**Advantages:** no immediate Production-domain disruption; TLS before cutover; clear Abort; separation from ERP.  
**Risks:** requires owner DNS change on a **non-Production** name; naming collisions if `migrate.` already used.

## Option B — Soviez-controlled temporary validation domain

Example: `<token>.migration.soviez.com`.

**Advantages:** easier reachability without customer DNS initially.  
**Risks:** SaaS dependency; must not relay payloads or expose ERP; brand/trust confusion; still needs customer-domain ownership proof before cutover.  
**Recommendation:** **allowed only as optional secondary** for connectivity lab — **not** canonical ownership proof for customer Production domain; **not** default.

## Option C — Direct customer Production domain preparation

Prepare/issue against `example.com` / `www` during Phase 18.

**Risks:** live routing impact; hard rollback; source disruption.  
**Recommendation:** **not default**; **forbidden** for routing attachment in Phase 18. Pre-issuance of Production cert without routing change is an **owner OD** (default **deny**).

## Canonical recommendation

**Option A** with default naming `migrate.<production-domain>`, owner-overridable exact FQDN, validated as single hostname (no wildcard proof).

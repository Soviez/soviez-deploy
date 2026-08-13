# HEALTH_AND_SMOKE_TEST_MODEL.md

## Purpose

Public **health gate** on Production FQDN resolving to destination — mandatory before `traffic_owner=destination` commit.

## Test tiers

### Tier 1 — Mandatory (BLOCKED on failure)

| Test | Signal |
|------|--------|
| DNS resolves to destination target | Propagation policy |
| TLS handshake + hostname match | Cert valid |
| HTTP → HTTPS redirect policy | nginx config |
| ERP `/web/login` reachable (200/302 expected) | App up |
| Database connectivity (internal probe via installer) | Data layer |
| License Guard accept destination bind | LG policy |
| Split-brain detector | Single public Production server |

### Tier 2 — Smoke (mandatory BLOCKED unless OD-16 waives)

| Test | Signal |
|------|--------|
| Authenticated session login (test user) | Auth stack |
| Read single known record (sanity query) | ORM |
| Static asset load | Filestore/nginx |
| Cron heartbeat neutralized still true pre-integration | Safety |

### Tier 3 — Optional (WARNING)

| Test | Signal |
|------|--------|
| IPv6 AAAA resolution | Dual-stack |
| WebSocket/long-poll endpoint | Realtime modules |
| Custom module probe | Tenant-specific |

## Execution context

- Run **after** DNS propagation observation.
- Run against **public** Production URL (not mig subdomain).
- Retry policy: exponential backoff, max 10 minutes total (OD-15).

## Report artifact

```json
{
  "schema": "soviez.migration_cutover_health.v1",
  "authorization_id": "...",
  "production_fqdn": "...",
  "overall": "PASS|WARNING|BLOCKED",
  "mandatory_failures": [],
  "optional_warnings": [],
  "observed_traffic_owner": "destination",
  "signed_at": "..."
}
```

## Relationship to Phase 21 readiness (Phase 20)

Phase 20 `phase21_readiness` validates **pre-cutover** state. Cutover health is **post-DNS** distinct report — do not conflate.

## Automatic rollback linkage

Mandatory health failure after DNS switch → trigger rollback evaluation (`AUTOMATIC_ROLLBACK_TRIGGERS.md`).

## OWNER DECISION REQUIRED

**OD-15:** Max health retry window before auto-rollback recommendation?

**Recommendation:** **10 minutes** mandatory tier; then **Needs Action** if owner must choose.

**OD-16:** Is authenticated login smoke **mandatory BLOCKED** or **WARNING**?

**Recommendation:** **Mandatory BLOCKED** for Production ERP cutover.

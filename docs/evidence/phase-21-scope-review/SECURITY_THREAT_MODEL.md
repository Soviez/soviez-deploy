# SECURITY_THREAT_MODEL.md

## Adversaries

| Actor | Goal |
|-------|------|
| Rogue operator | Force cutover without readiness |
| Network attacker | MITM during DNS propagation |
| Tenant attacker | Cross-account cutover hijack |
| Insider | Premature traffic_owner flip |
| Customer | Data loss during split epoch |

## Threat catalog

| ID | Threat | Mitigation |
|----|--------|------------|
| T-01 | Env flag bypass (`SOVIEZ_MIG_ALLOW_CUTOVER`) | Hard deny in prod; scoped operation gate only |
| T-02 | Forged cutover commit without health | Signed health artifact required in commit |
| T-03 | DNS hijack during propagation | Multi-resolver verify; TLS pin; maintenance on source |
| T-04 | Split-brain dual write | Source write block; AR-04 detector |
| T-05 | Rollback after payment capture | Needs Action; OD-20 threshold |
| T-06 | Cross-authorization cutover | Pair + authorization_id binding |
| T-07 | Stale Phase 21 readiness | TTL + drift invalidate |
| T-08 | License Guard bypass on dest | LG in mandatory health tier |
| T-09 | Webhook replay to both hosts | Disable source webhooks before dest enable |
| T-10 | Secret leakage in DNS instructions | No provider API keys in artifacts |
| T-11 | SaaS traffic relay injection | Explicitly forbidden architecture |
| T-12 | Stage hijack on public cutover | Entitlement re-check per Stage |
| T-13 | Automatic rollback abuse (DoS) | Advisory default; enforced subset only |
| T-14 | Tampered rollback window clock | UTC signed timestamps; ledger authority |
| T-15 | Legacy `--change-domain` invocation | Obsolete; operation engine only |

## Fail-closed gates

- Missing authorization → deny all cutover ops.
- BLOCKED readiness → deny plan.
- Split-brain detected → deny commit; recommend rollback.

## Audit requirements

- All sub-operations append to tamper-evident log (hash chain or signed JSON).
- Operator DNS attestation records operator identity (local account) — no secrets.

## LG gap risk

Without ERP first-class grace/traffic_owner states, attacker might confuse LG on destination — treat as **T-08**; mandatory health includes LG probe.

## OWNER DECISION REQUIRED

**OD-34:** Require dual-control for cutover commit (not just rollback)?

**Recommendation:** **Yes** for tenants with payment integrations.

**OD-35:** Sign DNS instructions with same key as cutover reports?

**Recommendation:** **Yes**.

# PRODUCTION_TLS_MODEL.md

## Scope

Production FQDN TLS on **destination host** immediately before public cutover. Distinct from Phase 18 mig-subdomain certificate.

## Reusable primitives (Phase 12)

| Module | Use |
|--------|-----|
| `src/ssl/challenge.sh` | HTTP-01 / DNS-01 for Production FQDN on destination |
| `src/ssl/promote.sh` | Atomic cert+nginx promote |
| `src/ssl/inventory.sh` | Cert expiry tracking |
| `src/nginx/ownership.sh` | Site ownership before promote |

## Sequence (Option C)

```text
production_route_activate (nginx server block exists, may use temporary/self-signed for nginx -t)
→ issue or promote Production cert on destination (LE recommended)
→ nginx -t + reload
→ TLS verify: chain valid, hostname match, expiry > rollback window + buffer
→ proceed to DNS instructions
```

## Preconditions

- DNS ownership proof from Phase 18 (control of zone).
- For HTTP-01: destination reachable on port 80/443 from internet **or** operator uses DNS-01.
- Production route nginx config references correct upstream.

## Validation checks

| Check | Failure |
|-------|---------|
| Certificate CN/SAN includes Production FQDN | BLOCKED |
| Not expired; not expiring within 24h | WARNING or BLOCKED (OD-11) |
| Private key local to destination | Required |
| No mixed-source cert reuse | BLOCKED — source cert must not be copied blindly |

## Rollback

- SSL promote rollback restores previous nginx+cert state on destination.
- Does not affect source Production TLS during rollback window.

## Phase 18 overlap

Mig-subdomain cert may remain for landing; Production cert is **separate** artifact in cutover report.

## OWNER DECISION REQUIRED

**OD-11:** Block cutover if Production cert expires within 24 hours?

**Recommendation:** **WARNING** if <7 days; **BLOCKED** if <24 hours.

**OD-12:** Require DNS-01 when HTTP-01 would expose destination before DNS switch?

**Recommendation:** **Allow either**; operator chooses based on provider capability.

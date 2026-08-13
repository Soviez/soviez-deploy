# DOMAIN_SSL_LIFECYCLE_MODEL.md (Phase 12)

## Objective

Post-provision Domain/SSL lifecycle for managed Production and Stage: monitoring, renewal, rotation, rollback, Nginx ownership, local repair — without reimplementing Phase 11 initial Stage domain/SSL provisioning.

## Non-goals

Initial Stage domain collection/uniqueness; initial trusted issuance; Stage create/clone/neutralization/origin cert; entitlement/tickets; retention; `--update`; backup/restore redesign; migration; automatic DNS-provider mutation; SaaS commercial/UI changes.

## Phase 11 vs Phase 12 ownership

| Area | Phase 11 | Phase 12 |
|------|----------|----------|
| Initial Stage domain/DNS/SSL gate | Owns | Preserves |
| Stage create / isolation / origin cert | Owns | Untouched |
| Post-provision renewal/rotation/expiry | — | Owns |
| Nginx ownership / safe reload / rollback | Initial stub | Owns long-running model |
| Production readiness until HTTPS | Partial | Owns explicit gate |
| Temporary HTTP | — | Provisioning-only |

## Production policy (owner-approved)

- Publicly trusted CA default; self-signed final PASS denied  
- Owner-approved private CA only when `SOVIEZ_SSL_ALLOW_PRIVATE_CA=1` (explicit)  
- Temporary HTTP only while provisioning; never “Production Ready” until trusted HTTPS  
- Automatic renewal default; lead time 30 days; warnings 30/14/7/3/1  
- Failure → Needs Action; never stops ERP  

## Stage policy

Same trusted-certificate baseline. Renewal failure never stops/deletes Stage. Certificate maintenance independent of Stage License entitlement. Local status/repair without SaaS.

## Renewal modes

`automatic` | `notify_only` | `manual` — configurable per environment; changing mode does not invalidate current cert.

## Retry/backoff

0–24h: every 6h; days 2–7: daily; after day 7: every 3 days; manual retry always available; no concurrent duplicate renewals.

## Wildcard / ACME

Wildcard optional, not default (`SOVIEZ_SSL_ALLOW_WILDCARD=1`). Default ACME: Let's Encrypt; isolated `fixture` provider for certification (no public Internet).

## Sovereignty / egress

Local-first monitoring and repair. No continuous phone-home. Challenges carry only operational binding metadata — no ERP/customer data.

## Future integration

Certbot/live Let's Encrypt on host; optional SaaS challenge verify only if required and egress-documented.

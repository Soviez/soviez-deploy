# INTEGRATION_ACTIVATION_MODEL.md

## Phase 20 baseline

Destination binding JSON flags (all `true` = neutralized):

- `mail_neutralized`
- `payments_neutralized`
- `webhooks_neutralized`
- `cron_neutralized`

## Activation policy

**All integrations remain OFF until public health PASS and `traffic_owner=destination`.**

## Incremental sequence (recommended)

```text
traffic_owner=destination
→ cron_business (controlled subset — OD-17)
→ outgoing_mail (SMTP test message to operator)
→ inbound_webhooks (register endpoints; no replay flood)
→ payment_providers (last — highest risk)
→ stage_public_integrations (if Stage cutover includes webhooks)
```

## Per-integration gates

| Integration | Pre-check | Activation | Rollback |
|-------------|-----------|------------|----------|
| Mail | SPF/DKIM DNS unchanged or updated in instruction addendum | Send test | Disable SMTP creds |
| Webhooks | URL now points to destination | Enable + secret rotate optional | Disable callbacks |
| Payments | Provider dashboard URL update manual doc | Enable capture | Disable + refund policy manual |
| Cron | Job list diff vs source | Enable non-destructive first | Pause all |

## Source side

- Source mail/webhooks/cron remain **disabled** during `cutover_maintenance` and after traffic_owner flip until Phase 22 archive.

## No SaaS relay

Payment and webhook traffic flows directly to destination Production URL — no SaaS proxy.

## OWNER DECISION REQUIRED

**OD-17:** Activate cron business jobs before or after mail?

**Recommendation:** **After mail test, before webhooks**.

**OD-18:** Require payment provider manual checklist completion before enable?

**Recommendation:** **Yes** — BLOCKED until operator attestation file present.

**OD-19:** Auto-rotate webhook secrets on cutover?

**Recommendation:** **WARNING** default; mandatory for high-risk tenants (owner list).

# ADMIN_OFFLINE_FIXTURES — Phase 9

## Admin grant API

`POST /api/admin/support/annual-grant`

### Request fixture

```json
{
  "accountId": "11111111-1111-1111-1111-111111111111",
  "licenseId": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "years": 2,
  "source": "manual_offline",
  "reason": "Invoice INV-2026-0042 paid via wire",
  "idempotencyKey": "admin-grant-fixture-001",
  "amountCents": 18000,
  "currency": "usd"
}
```

### Expected behavior

1. Validates license owned by account and active
2. Idempotent on `metadata.idempotency_key`
3. Inserts purchase:
   - `checkout_routing: admin_provision`
   - `stripe_checkout_session_id: admin-annual-{purchaseId}`
   - `status: paid`
   - `billing_type: prepaid_term`
   - `metadata.no_stripe_payment: true`
4. Calls `fulfillPrepaidAnnualSupport` with sourceType:
   - `manual_offline` → actor offline
   - `admin_grant` → actor admin
   - `complimentary` → source complimentary

### Source type mapping

| source param | coverage source_type | actor_type |
|--------------|---------------------|------------|
| manual_offline | manual_offline | offline |
| admin_grant | admin_grant | admin |
| complimentary | complimentary | admin |

## Admin revoke fixture

`revokeAnnualSupportAdmin` → RPC `support_reverse_coverage_period` with `revoked` event.

## Term discount admin fixtures

Certification harness (DB only):

```sql
INSERT INTO support_term_discount_rules (year_count, discount_percent, enabled, effective_from)
VALUES (2, 5.00, true, now());
```

Admin UI at `/admin/support-annual` exercises GET/POST/PATCH against live routes (manual QA, not automated in phase9-db).

## No fabricated Stripe settlement

Admin grants never insert `commercial_transactions.provider=stripe` with fake charge IDs. Provider follows D014 neutral model.

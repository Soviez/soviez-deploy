# REFUND_DISPUTE_REVOCATION — Phase 9

## Full refund

**Trigger:** Stripe refund where `amount_refunded >= amount_captured`

**Pipeline:** `stripe-refund-pipeline.ts`

1. Update purchase status refunded
2. `reverseCommercialLedgerForPurchase(..., fully_refunded)`
3. `reverseCoverageByIdempotencyKey(..., fully_refunded)`
4. Expire `user_addons` for purchase (annual + monthly slugs)

**Coverage:**

- Period `status → reversed`
- Event `fully_refunded` inserted

## Partial refund

**Trigger:** `0 < amount_refunded < amount_captured`

**Coverage:**

- Period `status → requires_admin_review`
- Event `partial_refund_requires_review`
- user_addons **unchanged**
- No automatic coverage day trim

See `PARTIAL_REFUND_HANDLING.md`.

## Dispute

Existing dispute pipeline integrated; coverage events include `disputed`, `dispute_won` types (schema support).

Dispute handling preserves Phase 3 commercial grant reversal patterns.

## Admin revocation

`revokeAnnualSupportAdmin` → RPC with `event_type: revoked`, `actor_type: admin`.

Requires original extension `idempotency_key`.

## Idempotency keys

| Context | Key source |
|---------|------------|
| Stripe prepaid purchase | `purchase.metadata.idempotency_key` |
| Fallback | `stripe-prepaid:{purchase_id}` |
| Event rows | `event:{event_type}:{idempotency_key}` |

Duplicate reverse calls: event idempotency prevents double-insert; period already reversed returns safely.

## Missing coverage row

If no matching coverage period (legacy purchase predating 084):

- `reverseCoverageByIdempotencyKey` treats GRANT_REVOKED/not found as **non-fatal**
- Refund pipeline continues

## Certification

Harness tests:

- Full reverse → status `reversed`
- Partial reverse → status `requires_admin_review`

Both **PASS** in `test:phase9-db`.

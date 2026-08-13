# PRODUCT_COMPATIBILITY — Phase 9

## New sales

| Product path | Phase 9 behavior |
|--------------|------------------|
| Annual prepaid (new) | ✅ Primary path via `/api/checkout/support/annual` |
| Monthly new checkout | ❌ 403 `MONTHLY_NEW_SALES_DISABLED` |
| Legacy recurring annual (`/checkout/support-subscription` year) | ✅ Preserved |

## Existing subscribers

| Legacy state | Technical support | Product updates | Portal status |
|--------------|-------------------|-----------------|---------------|
| Active prepaid coverage | ✅ | ✅ | `active` |
| Legacy recurring annual sub | ✅ | ✅ | `active`, legacyRecurring |
| Active monthly sub | ✅ | ❌ | `legacy_monthly` |
| Expired | ❌ | ❌ | `expired` / `not_covered` |

## Addon metadata

Migration updates `technical-support-annual` addon metadata hint:

```json
{
  "billing_model": "prepaid_term",
  "target_scope": "license",
  "technical_support": true,
  "product_updates": true,
  "phase9_annual": true
}
```

Non-destructive; does not alter live Stripe Price IDs.

## Commercial ledger

Prepaid fulfillment calls `syncCommercialLedgerForPurchase` — same dual-write pattern as Phase 3–4.

## Non-breaking guarantee

- Legacy support RPCs unchanged
- Existing monthly webhooks unchanged
- No drop of monthly `user_addons` rows

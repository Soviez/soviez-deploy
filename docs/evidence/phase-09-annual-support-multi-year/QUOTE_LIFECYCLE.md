# QUOTE_LIFECYCLE — Phase 9

## States

| State | Condition |
|-------|-----------|
| Active | `consumed_at IS NULL` AND `expires_at > now()` |
| Consumed | `consumed_at IS NOT NULL` (checkout session created) |
| Expired | `expires_at <= now()` AND not consumed |

## TTL

**15 minutes** — `ANNUAL_SUPPORT_QUOTE_TTL_MS = 15 * 60 * 1000`

## Flow

```
POST /api/support/annual/quote
  → validate license ownership + active status
  → load commercial settings (annual_prepaid_enabled, year bounds)
  → resolve discount rule for year_count
  → resolve addon pricing (country)
  → calculatePrepaidPriceCents
  → computeExtensionWindow (preview dates)
  → INSERT support_annual_quotes
  → return quoteId + pricing breakdown

POST /api/checkout/support/annual
  → loadAndValidateQuote (or create inline)
  → reject if consumed / expired / mismatch
  → recalculate price; reject PRICE_CHANGED
  → create Stripe session mode=payment
  → UPDATE quote consumed_at
  → INSERT pending purchase
```

## Denial codes by stage

| Stage | Codes |
|-------|-------|
| Quote create | LICENSE_REQUIRED, LICENSE_NOT_FOUND, WRONG_ACCOUNT, LICENSE_NOT_ELIGIBLE, ANNUAL_SUPPORT_DISABLED, TERM_NOT_AVAILABLE, DISCOUNT_RULE_NOT_FOUND |
| Checkout | QUOTE_EXPIRED, QUOTE_MISMATCH, PRICE_CHANGED, CHECKOUT_ALREADY_EXISTS |
| Fulfillment | LICENSE_REQUIRED, IDEMPOTENCY_CONFLICT |

## Validity preview

Quote includes non-binding preview:

- `validityPreviewStart` = computed extension_start
- `validityPreviewEnd` = computed extension_end

Actual coverage set at settlement via `support_extend_annual_coverage`.

## Tamper resistance

| Attack | Defense |
|--------|---------|
| Client changes years | Quote reload validates license_id + years match |
| Client changes price | Server quote final_amount_cents authoritative |
| Reuse consumed quote | CHECKOUT_ALREADY_EXISTS |
| Stale rule after quote | PRICE_CHANGED on checkout validation |

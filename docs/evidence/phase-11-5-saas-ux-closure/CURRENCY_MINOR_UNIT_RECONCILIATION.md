# CURRENCY_MINOR_UNIT_RECONCILIATION.md

## Rounding contract (Annual Support)

```text
base_total = annual_unit_price_cents × years
discount_amount = floor(base_total × discount_percent / 100)
final = max(0, base_total − discount_amount − coupon_discount_cents)
```

Source: `src/lib/annual-support/pricing.ts`

## Reconciliation chain (EG 2 years)

| Stage | Value |
|-------|-------|
| Price book (Annual addon EG) | 3,000,000 cents |
| Quote API `annualUnitPriceCents` | 3,000,000 |
| Quote `finalAmountCents` (10%) | 5,400,000 |
| Display | EGP 54,000.00 |
| Basket / Stripe Checkout | same minor units (Playwright Journey G/G2) |
| Commercial grant / coverage | prepaid extend; no retroactive reprice of prior periods |
| Customer UI | Total matches quote |

## Currencies verified

| Currency | Minor units | Display major | Stripe amount basis | Notes |
|----------|-------------|---------------|---------------------|-------|
| EGP | 2 | ÷100 | cents | PASS |
| SAR | 2 | ÷100 | cents | PASS |
| AED | 2 | ÷100 | fallback path | debt (no official Annual/Stage addon book) |

## Historical transactions

Existing coverage/entitlement rows remain; renewals use **current** addon localized unit, not prior License net purchase. Quote snapshots persist on `support_annual_quotes.pricing_snapshot`.

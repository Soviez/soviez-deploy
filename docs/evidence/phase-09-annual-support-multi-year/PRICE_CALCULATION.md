# PRICE_CALCULATION — Phase 9

## Formula (TS + SQL identical)

```
base_total_cents      = annual_unit_price_cents × years
discount_amount_cents = floor(base_total_cents × discount_percent / 100)
final_amount_cents    = max(0, base_total_cents − discount_amount_cents − coupon_discount_cents)
```

## Rounding policy

- **Floor** on percentage discount (never round up discount in customer's favor at percent step)
- Coupon applied **after** term discount
- Final amount clamped to ≥ 0

## Certified examples

### SQL harness (`support_calculate_prepaid_price_cents`)

| Input | Output |
|-------|--------|
| unit=10000, years=3, pct=10, coupon=500 | base=30000, discount=3000, final=26500 |

### TS unit test (`calculatePrepaidPriceCents`)

| Input | Output |
|-------|--------|
| unit=10000, years=3, pct=10, coupon=500 | base=30000, discount=3000, coupon=500, final=26500 |
| unit=1000, years=1, pct=0, coupon=5000 | final=0 (clamped) |

## Quote validation

Checkout re-calculates from stored quote fields + live rule check:

- Rule must still be enabled and in effective window
- Recalculated `final_amount_cents` must match quote row
- Mismatch → `PRICE_CHANGED`

Browser-supplied amounts are **ignored**.

## Pricing snapshot (immutable)

Stored on quote, purchase, and coverage period:

```json
{
  "calculation_version": "annual_support_v1",
  "annual_unit_price_cents": 10000,
  "years": 3,
  "discount_percent": 10,
  "discount_amount_cents": 3000,
  "coupon_code": null,
  "coupon_discount_cents": 500,
  "base_total_cents": 30000,
  "final_amount_cents": 26500,
  "currency": "usd",
  "country_code": "US",
  "pricing_source": "...",
  "discount_rule_id": "uuid",
  "license_id": "uuid",
  "quoted_at": "ISO8601"
}
```

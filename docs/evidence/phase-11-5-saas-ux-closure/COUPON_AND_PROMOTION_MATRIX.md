# COUPON_AND_PROMOTION_MATRIX.md

## Calculation order (Annual Support)

1. Resolve localized Annual **addon** unit (country price book / fallback)  
2. `base_total = unit × years`  
3. Apply term discount: `floor(base_total × discount_percent / 100)`  
4. Subtract optional server `couponDiscountCents` when stacking enabled  
5. `final = max(0, …)`  

Setting: `support_commercial_settings.coupon_stacking_with_term_discount = true`

## License coupons (demo)

| Code | Scope | Effect on Annual reference unit |
|------|-------|----------------------------------|
| GET10 | `base_license_only` | Does **not** alter Annual unit |
| OFF10 | `global_cart` | Cart-level; not auto-applied to Annual unit in quote API |
| SME-* | `base_license_only` | License-only; not Annual reference |

## First-term Support promotion

- Dedicated table `support_first_term_promotions` **not present**  
- Optional path: server-supplied `couponDiscountCents` on quote  
- Must remain separately configured from License coupons (policy preserved in code: License coupon does not redefine 20% base)

## Combinations

| Combo | Result |
|-------|--------|
| License coupon only | Affects License purchase path; Annual unit unchanged |
| Multi-year Support discount only | PASS (matrix) |
| Support coupon cents + term discount | Allowed when stacking true; applied after term discount |
| Renewal after initial promotion | Uses current unit + term rules; prior promo not forced |
| Invalid / foreign License | Blocked |
| Monthly new sales | `MONTHLY_NEW_SALES_DISABLED` |

## Cross-product

Stage License priced independently via Stage addon book — License coupons do not redefine Stage monthly unit.

# DISCOUNT_RULE_MATRIX — Phase 9

## Default seed (migration 084)

| year_count | discount_percent | enabled | scope |
|------------|------------------|---------|-------|
| 1 | 0.00 | true | global |

Multi-year discounts **must** be configured by admin — not seeded.

## Commercial settings defaults

| Setting | Default |
|---------|---------|
| min_years | 1 |
| max_years | 5 |
| default_years | 1 |
| max_discount_percent | 50.00 |
| monthly_new_sales_enabled | false |
| annual_prepaid_enabled | true |
| coupon_stacking_with_term_discount | true |
| calculation_version | annual_support_v1 |

## Rule resolution order

1. country + currency match (most specific)
2. country only
3. global (both NULL)
4. Most recent `effective_from` within active window

## Trigger enforcement (certified)

| Case | Result |
|------|--------|
| discount_percent > max_discount_percent | `DISCOUNT_PERCENT_EXCEEDS_MAX` |
| Overlapping active rule same year_count + scope | `OVERLAPPING_ACTIVE_DISCOUNT_RULE` |
| No rule for requested years | `DISCOUNT_RULE_NOT_FOUND` |
| years outside min/max | `TERM_NOT_AVAILABLE` |

## Admin API

- Create: `POST /api/admin/support/term-discounts`
- Patch rule/settings: `PATCH /api/admin/support/term-discounts`
- UI: `/admin/support-annual`

## Certification fixture

Certification inserts 2-year @ 5% rule for overlap/max tests only (harness DB, not production seed).

# COVERAGE_EXTENSION_MATRIX — Phase 9

## Extension formula

```
extension_start = max(support_current_annual_valid_until(license_id), settlement_at)
extension_end   = support_add_calendar_years(extension_start, years)
```

## Certified scenarios

| Scenario | settlement | prior valid_until | extension_start | extension_end (years=1) |
|----------|------------|-------------------|-----------------|-------------------------|
| No prior coverage | 2026-01-15 | null | 2026-01-15 | 2027-01-15 |
| Active stack | 2026-03-01 | 2030-06-01 | 2030-06-01 | 2031-06-01 |
| Leap day clamp | 2024-02-29 | — | — | 2025-02-28 (+1y) |
| Expired prior | 2020-01-01 | (expired) | settlement | +years from settlement |

## Source types

| source_type | Origin |
|-------------|--------|
| stripe_prepaid | Stripe Checkout fulfillment |
| stripe_legacy_subscription | Legacy recurring (future backfill) |
| manual_offline | Admin wire/check |
| admin_grant | Admin panel grant |
| complimentary | Complimentary grant |
| legacy_backfill | Migration backfill (reserved) |

## Status values

| status | Meaning |
|--------|---------|
| active | Counts toward valid_until |
| reversed | Full refund / revoke |
| superseded | Replaced (reserved) |
| requires_admin_review | Partial refund pending admin |

## Concurrency

Two parallel extensions on same license serialize via advisory lock — certified with concurrent harness test (different idempotency keys → sequential stack).

## Idempotency

Same `idempotency_key` → returns existing period; count remains 1.

## Event audit

Each extension inserts `support_coverage_events` row:

- `event_type: extended`
- `idempotency_key: event:extended:{idempotency_key}`

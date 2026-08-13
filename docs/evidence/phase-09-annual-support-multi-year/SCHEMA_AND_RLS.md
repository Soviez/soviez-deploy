# SCHEMA_AND_RLS — Phase 9

**Migration:** `084_annual_support_multi_year.sql`

## Tables

| Table | Rows (seed) | RLS |
|-------|-------------|-----|
| `support_commercial_settings` | 1 singleton | authenticated SELECT; service_role ALL |
| `support_term_discount_rules` | 1 (1y @ 0%) | authenticated SELECT enabled; service_role ALL |
| `support_coverage_periods` | — | authenticated SELECT own account; service_role ALL |
| `support_coverage_events` | — | authenticated SELECT own account; service_role ALL |
| `support_annual_quotes` | — | authenticated SELECT own account; service_role ALL |

## RPC security

| Function | PUBLIC | anon | authenticated | service_role |
|----------|--------|------|---------------|--------------|
| `support_extend_annual_coverage` | REVOKED | REVOKED | REVOKED | GRANT |
| `support_reverse_coverage_period` | REVOKED | REVOKED | REVOKED | GRANT |
| `support_resolve_annual_coverage` | REVOKED | — | GRANT | GRANT |
| `support_calculate_prepaid_price_cents` | — | — | GRANT | GRANT |
| `support_add_calendar_years` | — | — | GRANT | GRANT |

## Certified RLS tests

- **rls_anon:** anon role rejected on `support_commercial_settings` and `support_term_discount_rules` (permission denied / RLS)

## Purchase additive columns

- `prepaid_term_years INTEGER`
- `pricing_snapshot JSONB`
- `support_quote_id UUID`

## Constraints

- Discount overlap trigger: `OVERLAPPING_ACTIVE_DISCOUNT_RULE`
- Max discount: `DISCOUNT_PERCENT_EXCEEDS_MAX`
- Coverage idempotency: UNIQUE `idempotency_key`
- Event idempotency: UNIQUE `idempotency_key`

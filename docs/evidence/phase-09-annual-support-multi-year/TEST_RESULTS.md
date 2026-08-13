# TEST_RESULTS — Phase 9

**Date:** 2026-07-30  
**Host:** Docker Colima available for DB suite

## Unit + contract (`npm run test:phase9`)

**Result: 10/10 PASS**

| Test file | Tests | Status |
|-----------|-------|--------|
| `pricing.test.ts` | 7 | PASS |
| `routes.contract.test.ts` | 3 | PASS |

### pricing.test.ts

- calculatePrepaidPriceCents floor discount + coupon
- never negative final amount
- rejects invalid years
- addCalendarYearsUtc Feb 29 clamp (non-leap)
- addCalendarYearsUtc preserves Feb 29 (leap target)
- computeExtensionWindow stacks from valid_until
- computeExtensionWindow starts at settlement when no prior

### routes.contract.test.ts

- assertMonthlyNewSalesBlocked throws for month (403 MONTHLY_NEW_SALES_DISABLED)
- assertMonthlyNewSalesBlocked allows year/annual
- API route modules export HTTP handlers (quote, coverage, checkout, term-discounts, annual-grant)

## Docker DB (`npm run test:phase9-db`)

**Result: 11/11 PASS**

| Test | Result key |
|------|------------|
| discount rules enforce max percent and overlap trigger | discount_rules PASS |
| support_calculate_prepaid_price_cents floor rounding | price_calc_sql PASS |
| extension with no prior coverage starts at settlement | extension_no_prior PASS |
| extension stacks from active prior valid_until | extension_active PASS |
| support_add_calendar_years leap day clamp | leap_year PASS |
| extension idempotent by idempotency_key | idempotent PASS |
| concurrent extensions serialize per license | concurrent PASS |
| reverse full refund and partial review paths | reverse PASS |
| RLS denies anon direct reads | rls_anon PASS |
| monthly_new_sales disabled; monthly ≠ product_updates | monthly_capability_note PASS |
| expired coverage resolves as not allowed | extension_expired PASS |

Harness: isolated Postgres 16 container, migrations 078–084.

## Static analysis

| Command | Result |
|---------|--------|
| `npm run typecheck` | PASS |
| `npm run lint` | PASS |

## Build

| Command | Result |
|---------|--------|
| `npx next build` | Run separately; migrations to live skipped |

## Not tested (explicit)

- Live Stripe Checkout / webhooks
- Live Supabase production apply of 084
- End-to-end browser portal flow
- Admin UI manual click-through

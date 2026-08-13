# SUPPORT_PRICING_AND_CHECKOUT.md

## UI wiring (real app)

Instance → Support & Updates:

- English Annual Support pricing copy (20% of localized License list; multi-year discounts 0/10/15/20/25%)
- Year selector + quote via `POST /api/support/annual/quote`
- Checkout via `POST /api/checkout/support/annual` with `slaAccepted: true` + `idempotencyKey`
- Legacy monthly messaging path when summary marks legacy
- Marketplace continues to filter out Monthly Support new sales

## Demo environment result (PARTIAL)

Against the isolated Supabase demo project:

```
POST /api/support/annual/quote
→ {"error":"Could not find the table 'public.support_commercial_settings' in the schema cache"}
```

Cause: migrations `084_annual_support_multi_year.sql` (and dependents) are not present on the demo database. Direct Postgres (`db.*.supabase.co`) is not reachable from this host (IPv6-only / EHOSTUNREACH), so migrations could not be applied in this pass.

## Unit coverage still green

`npm run test:phase9` — 10/10 pass (pricing math + monthly new-sale block contracts).

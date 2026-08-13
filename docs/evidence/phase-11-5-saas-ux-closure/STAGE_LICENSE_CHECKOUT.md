# STAGE_LICENSE_CHECKOUT.md

## UI wiring

Instance → Stage License uses real APIs:

- `POST /api/stage-license/quote`
- `POST /api/checkout/stage-license` (idempotency key)
- Existing-Stages-unaffected copy from summary notes

## Demo environment result (PARTIAL)

```
POST /api/stage-license/quote
→ {"error":"STAGE_LICENSE_DISABLED","code":"STAGE_LICENSE_DISABLED"}
```

Demo DB lacks Stage License commercial foundation / enablement (migration `085_stage_license_monthly.sql` not applied; same DB connectivity blocker as Annual Support).

## Unit coverage

`npm run test:phase10` / contracts remain available in-repo (not re-blocked by UI shell work).

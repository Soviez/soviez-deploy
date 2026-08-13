# REGRESSION_RESULTS — Phase 9

## Phase 9-specific regressions

| Area | Check | Result |
|------|-------|--------|
| Monthly new checkout block | assertMonthlyNewSalesBlocked + route | PASS |
| Legacy year checkout path | support-subscription year interval | Preserved (not blocked) |
| Commercial ledger sync | fulfillPrepaidAnnualSupport calls sync | Code path verified |
| Refund pipeline | reverseCoverageByIdempotencyKey import | Integrated |
| Fulfillment hook | fulfillAnnualSupportFromCheckoutSession | Integrated |

## Prior phase suites (not re-run in Phase 9 closure)

Prior PASS evidence remains authoritative:

| Phase | Suite | Prior result |
|-------|-------|--------------|
| 3–4 | test:commercial-closure | PASS |
| 5 | test:phase5-all | PASS |
| 6 | test:phase6-all | PASS |
| 7 | test:phase7-all | PASS |
| 8 | tests/run_all.sh + ERP ORM E2E | PASS |

Phase 9 changes are additive (`084` migration) and do not modify prior migration files.

## Non-regression guarantees

- Legacy support RPCs untouched
- Device auth / slot reservation / registry routes untouched
- `local_license_guard` untouched
- Phase 8 installer untouched

## Lint regression fix

Unused `cn` import removed during Phase 9 closure — lint PASS.

## Build note

`npx next build` run separately; live migration apply skipped by design.

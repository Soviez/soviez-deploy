# COMPENSATION_POLICY.md

| Case | Policy |
|------|--------|
| A — SaaS fails before commit | Token available; no binding; source unchanged; safe retry |
| B — Commit OK, destination local apply fails | No second token; retry apply; source traffic owner; dest non-public; `…_local_apply_pending` |
| C — Dest apply OK, source grace fails | Dest stays non-public; recovery; Phase 21 blocked |
| D — Stage rebind partial | Authorization may stay committed; mandatory BLOCKED; optional WARNING; exact Stage retry |
| E — Result lost after commit | Query idempotency key; same signed result |
| F — Owner rollback before Phase 21 | **No automatic refund.** Exceptional admin reversal only if never trafficked + both bindings safely restorable; ledgered; never local silent unconsume (OD) |

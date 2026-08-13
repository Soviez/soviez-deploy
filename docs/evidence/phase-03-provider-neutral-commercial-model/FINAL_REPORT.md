# Phase 3 Evidence — Provider-Neutral Commercial Foundation

**Date:** 2026-07-30  
**Verdict:** **PARTIAL**  
**Scope:** `soviez-saas` additive commercial ledger only. No commit/push/deploy/live Stripe/production data.

---

## 1. Repository baseline

| Field | Value |
|-------|--------|
| Repo | `/Volumes/PortableSSD/soviez-project/soviez-saas` |
| Branch | `main` |
| Commit (pre-change / still HEAD) | `2f2f13c655ac42aa976764db56d939bf60a40094` |
| Working tree | Dirty with Phase 3 uncommitted changes only (no commit performed) |

Unrelated dirty files: **none** at Phase 3 start (clean tree recorded).

---

## 2. Baseline commands / results

| Command | Result |
|---------|--------|
| `git rev-parse HEAD` | `2f2f13c655ac42aa976764db56d939bf60a40094` |
| Product `*.test.ts` inventory | No pre-existing product Stripe/slot fixture suite under `src/` suitable for full webhook e2e |
| `npm run test:commercial` | **11/11 PASS** (see `test-commercial.txt`) |
| `npm run typecheck` | **PASS** (exit 0) |
| `npm run lint` | **PASS** — no ESLint warnings or errors |
| `npx next build` | **PASS** (exit 0; run without `apply-migrations` against live DB) |
| `npm run db:migrate:dry-run` | Lists `078_provider_neutral_commercial_ledger.sql` (not applied live) |
| Isolated Docker Postgres apply + backfill | **PASS** (see `isolated-pg-smoke.txt`) |
| RLS authenticated write denial | **PASS** — `permission denied for table commercial_transactions` (`rls-smoke.txt`) |

---

## 3. Schema / migration summary

**Migration:** `soviez-saas/supabase/migrations/078_provider_neutral_commercial_ledger.sql`

### Tables (additive)

1. `commercial_transactions` — provider-neutral commercial event  
2. `commercial_grants` — commercial right (capability + quantity + validity)  
3. `commercial_grant_allocations` — future-safe consumption/allocation ledger (reservation machine **not** implemented)

### RPCs

- `backfill_commercial_ledger_from_purchases()` — deterministic, idempotent  
- `get_neutral_available_license_slots(uuid)` — **shadow/diagnostic only**; does **not** replace `get_available_license_slots`

### Guarantees

- No drop/rename of existing public columns, enums, RPCs, or tables  
- Extensible `provider` **text** (no enum explosion per gateway)  
- Unique `idempotency_key` on transactions, grants, allocations  
- RLS enabled; anon denied; authenticated SELECT own only; no authenticated writes; service_role ALL  
- Stub `anon`/`authenticated`/`service_role` created **if missing** (isolated PG smoke)

### Backfill classification (verified in isolated PG)

| Legacy shape | provider | settlement_status | provider_reference |
|--------------|----------|-------------------|--------------------|
| Real Stripe `cs_*` paid | `stripe` | `settled` | present |
| Real Stripe refunded | `stripe` | `fully_refunded` | present |
| `admin-grant-*` / `admin_provision` | `admin_grant` | `manually_approved` | **NULL** (no fake Stripe settlement) |

Second backfill: same logical counts (idempotent; `tx_count=3`, `grant_count=3`).

---

## 4. Dual-write / dual-read

| Path | Behavior |
|------|----------|
| Stripe Checkout fulfillment | Dual-write via `syncCommercialLedgerForPurchase` |
| Admin license / add-on provision | Dual-write; source `admin_grant` |
| Subscription sync | Dual-write sync |
| Refund | `reverseCommercialLedgerForPurchase` |
| Dispute created/lost/won | Mark disputed / chargeback / reinstate helpers |
| License generate | Consumption sync to neutral grant |
| License Slot **authorization** | **Still legacy** `purchases` RPCs |
| Neutral slot calc | Shadow only (`get_neutral_*` + TS parity helpers) |

---

## 5. License Slot parity matrix

| Scenario | Legacy | Neutral | Match |
|----------|--------|---------|-------|
| Stripe-paid available Slot | 1 | 1 | ✔ (`logic.test.ts`) |
| Admin-granted available Slot | 1 | 1 | ✔ |
| Consumed Slot | 0 | 0 | ✔ |
| Refunded purchase | 0 | 0 | ✔ |
| Multiple purchases | sum | sum | ✔ |
| No available Slots | 0 | 0 | ✔ |
| Isolated SQL: Stripe+admin paid, refunded excluded | — | 2 | ✔ (`get_neutral_available_license_slots`) |
| Duplicate webhook / retry | idempotency_key unique | dual-write upsert | Constrained (integration not fixture-run) |
| Disputed/revoked | legacy refund/dispute pipelines unchanged + dual-write revoke | revoked grant | Wired; no live Stripe dispute fixture |

**Production authorization decision source unchanged:** `get_available_license_slots` / `generate_secure_license_1to1`.

---

## 6. RLS / security

| Check | Result |
|-------|--------|
| Authenticated INSERT into `commercial_transactions` | Denied (`permission denied`) |
| Policies present on commercial tables | 12 policies |
| Public generic “create grant” API | **Not** added |
| Admin grants | Continue through existing authorized admin APIs + dual-write |

Not executed: JWT cross-account SELECT denial under full Supabase Auth stack (auth.uid stubbed in isolated PG).

---

## 7. Changed files

### Created (`soviez-saas`)

- `supabase/migrations/078_provider_neutral_commercial_ledger.sql`
- `src/lib/commercial/logic.ts`
- `src/lib/commercial/logic.test.ts`
- `src/lib/commercial/index.ts`
- `docs/COMMERCIAL_LEDGER_PHASE3.md`

### Modified (`soviez-saas`)

- `package.json` (`test:commercial`, `typecheck`)
- `src/lib/fulfill-checkout-session.ts`
- `src/lib/admin-provisioning.ts`
- `src/lib/stripe-refund-pipeline.ts`
- `src/lib/stripe-dispute-pipeline.ts`
- `src/lib/stripe-subscription-pipeline.ts`
- `src/app/api/license/generate/route.ts`
- `src/types/database.ts` (Functions entries; table Row types still via cast)

### Created/updated (`soviez-sh`)

- `docs/evidence/phase-03-provider-neutral-commercial-model/*`
- `PROJECT_STATE.md`, `docs/ai/*`, `docs/dev/*` (Phase 3 status)

---

## 8. Why PARTIAL (not PASS)

1. No fixture-based Stripe Checkout / webhook e2e against a full Supabase stack (live Stripe forbidden; local fixture harness not present).  
2. No browser/portal load verification for invoice/license/support/admin UI.  
3. Generated `Database` table Row/Insert types for new tables incomplete (`as never` casts).  
4. Cross-account RLS SELECT under real JWT not proven in isolated stub.  

Foundation schema, dual-write wiring, unit parity, isolated migration/backfill/RLS-write denial, lint/typecheck/build **did** pass.

---

## 9. Unresolved owner / business decisions (not introduced)

- Soft-revoke slot reuse  
- Partial-refund commercial grant policy beyond current legacy behavior (preserve + document)  
- `past_due` entitlement  
- Timing to nullable synthetic Stripe session columns (retain for now)  
- Apply `078` to staging/production (requires explicit owner auth)

---

## 10. Forbidden actions (confirmed not done)

- No commit / push / merge / tag / deploy  
- No live Supabase data mutate / migrate against production  
- No live Stripe product changes  
- No installer / `local_license_guard` / Device Auth / registry / Stage product / Docker publishing  

---

## 11. Next allowed phase

**Phase 4 — Capability and entitlement model**  
**Implementation of Phase 4 is NOT authorized** until owner reviews this PARTIAL Phase 3 gate.

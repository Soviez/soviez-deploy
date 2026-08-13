# Phase 4 Evidence — Capability and Entitlement Foundation

**Date:** 2026-07-30  
**Verdict:** **PARTIAL**  
**Scope:** `soviez-saas` additive capability catalog + entitlement resolver on Phase 3 grants. No commit/push/deploy/live Stripe/production data.

---

## Baselines

| Field | Value |
|-------|--------|
| SaaS branch | `main` |
| SaaS commit | `2f2f13c655ac42aa976764db56d939bf60a40094` |
| Dirty state preserved | Phase 3 files retained; Phase 4 additive on top |
| Phase 3 verdict | PARTIAL (usable foundation) |
| Baseline `test:commercial` | 11/11 PASS |
| Baseline typecheck | PASS |

See `baseline.txt`, `CALL_SITE_INVENTORY.md`.

---

## Migration summary

**079_capability_entitlement_foundation.sql**

- `commercial_capabilities` (8 seeded codes)
- `commercial_capability_mappings` (monthly/annual/legacy/slot/token)
- `materialize_capability_grants_from_commercial()` — annual+license → `product_updates`
- `resolve_capability_entitlement(...)` — service-role strict resolver
- `get_capability_available_quantity(...)` — shadow quantity
- RLS: catalog read (active) for authenticated; mappings service-only; no client writes
- Time: UTC; `valid_from` inclusive; `valid_until` exclusive

Isolated Docker PG: 078+079 apply EXIT 0; backfill 4; materialize creates 1 product_updates; idempotent unique key; RLS write denied.

---

## Capability catalog seed

`license_slot`, `technical_support`, `product_updates`, `stage_environments`, `migration_token`, `private_image_pull`, `automatic_activation`, `offline_update_bundle`

None auto-granted except via commercial grants + mappings.

---

## Mapping matrix

| Source | technical_support | product_updates | license_slot | migration_token |
|--------|-------------------|-----------------|--------------|-----------------|
| monthly slug | yes | no | — | — |
| annual slug + exact license | yes | yes | — | — |
| annual unbound | yes | **no** | — | — |
| legacy support slug | yes | **no** (fail closed) | — | — |
| license purchase | — | — | yes | — |
| ip-migration-token | — | — | — | yes |

---

## Materialization strategy

**Hybrid:** grant rows (Phase 3) + catalog/mappings + mapped expansion into additional grant rows. Resolver reads grants only — no Stripe.

---

## Resolver / exact-license (isolated + unit)

| Check | Result |
|-------|--------|
| Annual updates for License A | allowed=true |
| Same account License B | denied |
| Missing license_id | LICENSE_REQUIRED |
| Unbound updates | UNBOUND_LEGACY_GRANT (unit) |
| Cross-account license | WRONG_ACCOUNT (unit) |
| Monthly → product_updates | no mapping / denied |
| Support account boolean | allowed |

---

## Parity

| Area | Result | Cutover |
|------|--------|---------|
| License Slot | unit parity PASS | No — legacy RPC SoT |
| Migration Token | unit shadow PASS when wallets aligned | No — legacy burn SoT |
| Technical support | legacy RPCs unchanged | No |

---

## Tests

| Command | Result |
|---------|--------|
| `npm run test:phase4` | **35/35 PASS** |
| `npm run typecheck` | PASS |
| `npm run lint` | PASS (no warnings after unused-var fix) |
| `npx next build` | PASS |
| Isolated PG 078+079 | PASS |
| Stripe/admin/portal e2e | **NOT RUN** → PARTIAL |

---

## Why PARTIAL

1. No fixture Stripe webhook / admin API / portal load e2e  
2. Phase 3 still PARTIAL underneath  
3. Migration-token wallet vs grant parity requires dual-write alignment in live data (unit proves formula; no live DB apply)  
4. Generated table Row types incomplete (`as never` casts remain)

---

## Forbidden actions confirmed

No installer / guard / Docker / live Stripe / live Supabase mutate / commit / push / deploy.

---

## Next allowed phase

**Phase 5 — Device authorization** — **NOT authorized**.

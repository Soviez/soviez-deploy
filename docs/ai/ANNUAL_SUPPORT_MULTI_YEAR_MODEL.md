# Annual Support Multi-Year Model (Phase 9)

**Status:** Implemented — **PASS** (2026-07-30)  
**Implementation repo:** `soviez-saas`  
**Migration:** `084_annual_support_multi_year.sql`  
**Developer protocol:** `docs/dev/ANNUAL_SUPPORT_PROTOCOL.md`

---

## Objective

Deliver a **provider-neutral**, **license-bound**, **prepaid multi-year** Annual Technical Support product where:

1. **New sales are Annual-only** — monthly support checkout for new customers is blocked server-side.
2. **Multi-year terms** (1–5 years by default, admin-configurable) use **admin-defined term discount rules**, not hard-coded percentages.
3. **Exact license binding** — every quote, checkout, grant, and coverage period is tied to a specific `license_id` owned by the account.
4. **Early renewal extends** from `max(current_valid_until, settlement_time)` using calendar-year arithmetic.
5. **Immutable pricing snapshots** at quote/checkout/grant time — later admin rule changes do not mutate history.
6. **Coverage history** is authoritative (`support_coverage_periods` + events); mutable `user_addons.current_period_end` is a compatibility mirror only.
7. **Runtime independence** — Annual Support expiration does **not** deactivate Soviez ERP, block login, remove data, or block backup/restore. It affects only covered technical support and future product updates.

---

## Non-goals (this phase)

| Excluded | Notes |
|----------|-------|
| Installer `--update` wiring | Deferred to a later phase; no ERP phone-home for update checks |
| Live Stripe / Supabase migration apply | Migration `084` certified in isolated Docker only |
| Monthly subscriber migration policy | Existing monthly renewals continue; new monthly sales blocked (D008 unresolved) |
| N-year Stripe **subscription** | Prepaid uses Stripe Checkout `mode=payment`, not recurring subscription |
| Automatic partial-refund proration | Partial refunds set `requires_admin_review`; no automatic coverage trim (D015) |
| Breaking legacy monthly renewals | Existing `user_addons` monthly rows and webhooks unchanged |
| Product update delivery mechanism | Entitlement foundation only; no installer pull gate in this phase |

---

## Provider-neutral architecture

Commercial truth flows through **coverage periods** and **commercial ledger sync**, not Stripe object inspection at entitlement time.

```
Customer quote/checkout/grant
        │
        ▼
support_annual_quotes (short-lived, server-priced)
        │
        ▼
purchases (prepaid_term, pricing_snapshot, support_quote_id)
        │
        ▼
support_extend_annual_coverage RPC  ──► support_coverage_periods (immutable history)
        │                                      │
        ▼                                      ▼
user_addons mirror (compatibility)     support_coverage_events (audit)
        │
        ▼
syncCommercialLedgerForPurchase ──► commercial_grants
        │
        ▼
support_resolve_annual_coverage / readAnnualCoverageForLicense (provider-neutral read)
```

**Principle:** `support_resolve_annual_coverage(license_id)` answers coverage without asking whether Stripe, admin, or offline settlement was used.

Admin/offline grants use `checkout_routing: admin_provision`, synthetic session IDs (`admin-annual-*`), and `metadata.no_stripe_payment: true`. They never fabricate Stripe settlement in the neutral model (D014).

---

## Annual-only new sales

- `support_commercial_settings.monthly_new_sales_enabled` defaults to **`false`**.
- `POST /api/checkout/support-subscription` returns **403** `MONTHLY_NEW_SALES_DISABLED` when `interval === "month"`.
- `assertMonthlyNewSalesBlocked("month")` enforces the same rule in library code.
- **Legacy monthly subscribers** retain active coverage via existing `user_addons` rows; portal coverage API surfaces `legacy_monthly` status with denial code `MONTHLY_DOES_NOT_INCLUDE_UPDATES` for product updates.

New Annual checkout path: `POST /api/checkout/support/annual` (prepaid, `mode=payment`).

---

## Legacy monthly compatibility

| Scenario | Technical support | Product updates | Portal status |
|----------|-------------------|-----------------|---------------|
| Active prepaid annual coverage | ✅ | ✅ | `active` |
| Legacy recurring annual subscription | ✅ | ✅ | `active`, `legacyRecurring: true` |
| Active monthly subscription | ✅ | ❌ | `legacy_monthly` |
| Expired / none | ❌ | ❌ | `expired` / `not_covered` |

Monthly legacy does **not** receive `product_updates` capability grants (Phase 4 rule preserved).

---

## Pricing

- **Unit:** annual list price from `technical-support-annual` addon + country pricing (`resolveAddonPricing`).
- **Base total:** `annual_unit_price_cents × years`
- **Term discount:** admin rule per `year_count` (scoped globally, by country, or country+currency).
- **Coupon:** applied **after** term discount when `coupon_stacking_with_term_discount` is enabled.
- **Rounding:** `discount_amount = floor(base_total × discount_percent / 100)`; `final = max(0, base − discount − coupon)`.
- **Calculation version:** `annual_support_v1` (stored on quotes and snapshots).
- **Seed:** migration inserts **1-year @ 0% only**; multi-year discounts require admin configuration.

---

## Discount rules

Stored in `support_term_discount_rules`:

- `year_count` (1–25)
- `discount_percent` (0–100, capped by `support_commercial_settings.max_discount_percent`, default 50%)
- `enabled`, `effective_from`, `effective_until`
- Optional `country_code` + `currency` scope
- **Overlap prevention:** trigger rejects overlapping active rules for same year_count + scope
- **Resolution order:** country+currency → country → global; most recent `effective_from` wins

---

## Quote lifecycle

1. Customer selects license + term years.
2. `POST /api/support/annual/quote` validates ownership, resolves discount rule, calculates price, previews extension window, persists quote.
3. Quote TTL: **15 minutes** (`ANNUAL_SUPPORT_QUOTE_TTL_MS`).
4. Checkout loads quote by `quoteId` or creates inline quote; **re-validates** rule + price before Stripe session.
5. Browser-supplied amounts are **never trusted**; server quote `final_amount_cents` wins.
6. On checkout session creation, quote marked `consumed_at`.
7. Tamper attempts → `QUOTE_MISMATCH`, `PRICE_CHANGED`, or `QUOTE_EXPIRED`.

---

## Prepaid term (not subscription)

Stripe Checkout uses:

- `mode: "payment"` (one-time)
- `checkout_kind: "annual_support_prepaid"` metadata
- `billing_model: "prepaid_term"`
- `prepaid_term_years: N`
- `target_license_id`, `support_quote_id`, `calculation_version`, `idempotency_key`

Fulfillment on `checkout.session.completed` calls `fulfillAnnualSupportFromCheckoutSession` → `fulfillPrepaidAnnualSupport`.

---

## Exact license binding

Every commercial action requires a **specific active license** owned by the account:

- Quote: `license_id` FK + ownership check
- Checkout: `resolveCheckoutTargetLicense` + metadata `target_license_id`
- Coverage extension: `support_extend_annual_coverage(p_license_id, ...)`
- Admin grant: explicit `licenseId` + ownership validation
- Coverage read: `GET /api/support/annual/coverage?licenseId=...`

Cross-license support denial is implicit (wrong account → 403; no coverage row → expired).

---

## Extension semantics

```
extension_start = max(support_current_annual_valid_until(license_id), settlement_at)
extension_end   = support_add_calendar_years(extension_start, years)
```

- **Calendar years** in UTC; Feb 29 → Feb 28 on non-leap target years.
- **Concurrent extensions** per license serialized via `pg_advisory_xact_lock(hashtextextended(license_id))`.
- **Idempotency:** same `idempotency_key` returns existing period row.
- **Stacking:** early renewal while active extends from current end, not from today.

---

## Capabilities

| Capability | Scope | Prepaid annual | Legacy monthly | Expired |
|------------|-------|----------------|----------------|---------|
| `technical_support` | account/license | ✅ | ✅ (legacy RPC) | ❌ |
| `product_updates` | license (strict) | ✅ iff license bound | ❌ fail closed | ❌ |

Materialization via `syncCommercialLedgerForPurchase` after prepaid fulfillment. Strict resolver unchanged for installer cutover.

Portal coverage API exposes `includesTechnicalSupport` and `includesProductUpdates` per license.

---

## Refund / dispute / revocation

| Event | Coverage action | user_addons | Commercial ledger |
|-------|-----------------|-------------|-------------------|
| Full refund | `status → reversed` | `expired` | `fully_refunded` reverse |
| Dispute | `disputed` event | per existing pipeline | disputed |
| Admin revoke | `revoked` | manual follow-up | revoked |
| Partial refund | `requires_admin_review` | **unchanged** | partial per legacy |

Full refund idempotency key: purchase `metadata.idempotency_key` or `stripe-prepaid:{purchase_id}`.

---

## Partial-refund REQUIRES_ADMIN_REVIEW (unresolved policy)

**Decision D015 preserved:** automatic partial-refund proration is **not implemented**.

When Stripe reports `0 < amount_refunded < amount_captured`:

1. `support_reverse_coverage_period(..., 'partial_refund_requires_review')` sets period `status = requires_admin_review`.
2. Event `partial_refund_requires_review` recorded in `support_coverage_events`.
3. Coverage remains active until admin resolves manually.
4. Denial code `PARTIAL_REFUND_REQUIRES_REVIEW` reserved for future strict paths.

**Business policy for trimming coverage days on partial refund remains unresolved** — requires owner decision.

---

## Runtime independence

Annual Support is **optional commercial coverage**, not a runtime kill switch:

- Expiration does **not** deactivate ERP, block login, delete data, or block backup/restore.
- No installer phone-home for support status in this phase.
- `--update` integration (checking `product_updates` before pull) is a **later phase**.

This aligns with Sovereignty First constitution and user-facing privacy docs.

---

## Later `--update` integration (not this phase)

Future installer update flow will:

1. Call strict entitlement / coverage API with exact `license_id`.
2. Gate product update pull on active `product_updates` capability.
3. Fail closed with structured denial codes.

Phase 9 delivers the **data model, APIs, and commercial plumbing** only.

---

## Evidence

`docs/evidence/phase-09-annual-support-multi-year/FINAL_REPORT.md`

# Annual Support Protocol (Phase 9)

**Migration:** `soviez-saas/supabase/migrations/084_annual_support_multi_year.sql`  
**Library:** `soviez-saas/src/lib/annual-support/`  
**Model:** `docs/ai/ANNUAL_SUPPORT_MULTI_YEAR_MODEL.md`

---

## Schema (084)

### Tables

| Table | Purpose |
|-------|---------|
| `support_commercial_settings` | Singleton policy: min/max/default years, max discount %, feature flags |
| `support_term_discount_rules` | Auditable year-count discount rules (admin-configurable) |
| `support_coverage_periods` | Immutable coverage extension history per exact `license_id` |
| `support_coverage_events` | Audit trail: extended, refunded, disputed, revoked, partial review |
| `support_annual_quotes` | Server-priced, short-lived quotes |

### Purchase columns (additive)

| Column | Type | Notes |
|--------|------|-------|
| `prepaid_term_years` | INTEGER | NULL for legacy subscriptions |
| `pricing_snapshot` | JSONB | Immutable at settlement |
| `support_quote_id` | UUID | FK to quote used at checkout |

### RPCs / functions

| Function | Access | Purpose |
|----------|--------|---------|
| `support_add_calendar_years(start, years)` | authenticated, service_role | UTC calendar-year add; leap-day clamp |
| `support_current_annual_valid_until(license_id)` | authenticated, service_role | MAX active `extension_end` |
| `support_resolve_term_discount_rule(years, as_of, country?, currency?)` | service_role | Active rule resolution; raises on miss |
| `support_calculate_prepaid_price_cents(unit, years, pct, coupon?)` | authenticated, service_role | Pure price math (floor rounding) |
| `support_extend_annual_coverage(...)` | **service_role only** | Transaction-safe extension + event |
| `support_reverse_coverage_period(idempotency_key, event_type, ...)` | **service_role only** | Full reverse or partial review |
| `support_resolve_annual_coverage(license_id, as_of?)` | authenticated, service_role | Provider-neutral coverage JSONB |

### Triggers

- `support_term_discount_rules_no_overlap` — rejects overlapping active rules; enforces max discount percent

### Seed data

- `support_commercial_settings` row `id=1` with defaults (min=1, max=5, monthly_new_sales=false, annual_prepaid=true)
- One discount rule: **year_count=1, discount_percent=0%**

---

## API contracts

### POST `/api/support/annual/quote`

**Auth:** authenticated customer  
**Body:**

```json
{
  "licenseId": "uuid",
  "years": 1,
  "countryCode": "US",
  "couponCode": "optional"
}
```

**Success 200:**

```json
{
  "quoteId": "uuid",
  "licenseId": "uuid",
  "years": 1,
  "currency": "usd",
  "annualUnitPriceCents": 10000,
  "baseTotalCents": 10000,
  "discountPercent": 0,
  "discountAmountCents": 0,
  "couponCode": null,
  "couponDiscountCents": 0,
  "finalAmountCents": 10000,
  "discountRuleId": "uuid",
  "calculationVersion": "annual_support_v1",
  "validityPreviewStart": "ISO8601",
  "validityPreviewEnd": "ISO8601",
  "expiresAt": "ISO8601",
  "terms": {
    "includesTechnicalSupport": true,
    "includesProductUpdates": true,
    "billingModel": "prepaid_term",
    "runtimeIndependence": "..."
  }
}
```

**Errors:** `{ "error": "...", "code": "<DENIAL_CODE>" }`

---

### POST `/api/checkout/support/annual`

**Auth:** authenticated customer + rate limit (`checkout-support-annual`)  
**Body:**

```json
{
  "licenseId": "uuid",
  "years": 3,
  "quoteId": "uuid (optional)",
  "countryCode": "US (optional)",
  "couponCode": "optional",
  "idempotencyKey": "client-generated 8-128 chars",
  "slaAccepted": true
}
```

**Success 200:**

```json
{
  "url": "https://checkout.stripe.com/...",
  "purchaseId": "uuid",
  "sessionId": "cs_..."
}
```

Creates Stripe Checkout `mode=payment`, marks quote consumed, inserts pending purchase.

---

### GET `/api/support/annual/coverage?licenseId=uuid`

**Auth:** authenticated customer  
**Success 200:**

```json
{
  "licenseId": "uuid",
  "status": "active | expired | not_covered | legacy_monthly",
  "validUntil": "ISO8601 | null",
  "validFrom": "ISO8601 | null",
  "includesTechnicalSupport": true,
  "includesProductUpdates": true,
  "sourceType": "annual_support | legacy_monthly | legacy_recurring_annual | none",
  "renewalAvailable": true,
  "legacyRecurring": false,
  "denialCode": null,
  "runtimeNote": "..."
}
```

---

### GET/POST/PATCH `/api/admin/support/term-discounts`

**Auth:** admin session  

- **GET** — list all rules + commercial settings
- **POST** — create rule (`yearCount`, `discountPercent`, optional scope/window)
- **PATCH** — `{ kind: "rule", id, ... }` or `{ kind: "settings", minYears, ... }`

Admin audit actions: `SUPPORT_TERM_DISCOUNT_CREATE`, `SUPPORT_TERM_DISCOUNT_PATCH`, `SUPPORT_COMMERCIAL_SETTINGS_PATCH`.

---

### POST `/api/admin/support/annual-grant`

**Auth:** admin session  
**Body:**

```json
{
  "accountId": "uuid",
  "licenseId": "uuid",
  "years": 2,
  "source": "manual_offline | admin_grant | complimentary",
  "reason": "required 3-500 chars",
  "idempotencyKey": "8-128 chars",
  "amountCents": 0,
  "currency": "usd"
}
```

**Success 200:**

```json
{
  "ok": true,
  "purchaseId": "uuid",
  "coveragePeriodId": "uuid"
}
```

Never creates Stripe payment. Purchase uses `checkout_routing: admin_provision`, synthetic session `admin-annual-{purchaseId}`.

---

## Pricing calculation + floor rounding

**TypeScript:** `calculatePrepaidPriceCents` in `src/lib/annual-support/pricing.ts`  
**SQL:** `support_calculate_prepaid_price_cents`

```
base_total_cents     = annual_unit_price_cents × years
discount_amount_cents = floor(base_total_cents × discount_percent / 100)
final_amount_cents   = max(0, base_total_cents − discount_amount_cents − coupon_discount_cents)
```

**Certified example:** unit=10000, years=3, discount=10%, coupon=500 → base=30000, discount=3000, final=26500.

Coupon stacking order: term discount first, then coupon (when enabled in settings).

---

## Quote lifecycle

| Stage | Action |
|-------|--------|
| Create | Insert `support_annual_quotes`; TTL 15 min |
| Preview | `validity_preview_start/end` from `computeExtensionWindow` |
| Validate checkout | Re-check rule enabled + price unchanged |
| Consume | Set `consumed_at` when Stripe session created |
| Expire | Reject with `QUOTE_EXPIRED` after `expires_at` |
| Tamper | `QUOTE_MISMATCH` if license/years/amount differ |

---

## Stripe mode=payment metadata

Checkout session metadata keys:

| Key | Value |
|-----|-------|
| `checkout_kind` | `annual_support_prepaid` |
| `billing_model` | `prepaid_term` |
| `prepaid_term_years` | string integer |
| `target_license_id` | UUID |
| `support_quote_id` | UUID |
| `calculation_version` | `annual_support_v1` |
| `idempotency_key` | client key |
| `final_amount_cents` | string integer |
| `currency` | lowercase ISO |
| `discount_rule_id` | UUID |
| `addon_slug` | `technical-support-annual` |
| `sla_accepted_at` | ISO8601 |
| `sla_text` | truncated SLA |

Stripe idempotency header: `annual-support-{idempotencyKey}`.

Fulfillment hook: `fulfillAnnualSupportFromCheckoutSession` in `fulfill-checkout-session.ts`.

---

## Extension transaction

`support_extend_annual_coverage` (SECURITY DEFINER):

1. Idempotency check (return existing if key matches)
2. `pg_advisory_xact_lock(hashtextextended(license_id))`
3. Re-check idempotency after lock
4. Compute window from `support_current_annual_valid_until`
5. INSERT coverage period + `extended` event
6. Return period row

TypeScript wrapper: `extendAnnualCoverage` → `fulfillPrepaidAnnualSupport` upserts `user_addons` + purchase + commercial ledger.

---

## Idempotency

| Layer | Key |
|-------|-----|
| Coverage extension | Client/server `idempotency_key` → UNIQUE on `support_coverage_periods` |
| Coverage events | `event:{type}:{idempotency_key}` → UNIQUE |
| Purchase checkout | `metadata.idempotency_key` on purchases |
| Stripe session | Header `annual-support-{key}` |
| Admin grant | Same purchase metadata pattern |

Duplicate extension calls return the same period row without double-extending.

---

## Concurrency (advisory lock)

Concurrent `support_extend_annual_coverage` calls for the same `license_id` serialize within the transaction via `pg_advisory_xact_lock`. Certified: two parallel 1-year extensions produce sequential stacked windows.

---

## Capability mapping

After prepaid fulfillment (`fulfillPrepaidAnnualSupport`):

1. `user_addons` row: `technical-support-annual`, `stripe_subscription_id: prepaid-{purchaseId}`
2. `purchases` updated: `billing_type: prepaid_term`, `prepaid_term_years`, `pricing_snapshot`
3. `syncCommercialLedgerForPurchase` → `commercial_grants` with `technical_support` + materialized `product_updates` (exact license)

Coverage read merges:

- `support_resolve_annual_coverage` (prepaid history)
- Legacy `user_addons` monthly / recurring annual fallbacks

---

## Denial codes

Stable codes from `ANNUAL_SUPPORT_DENIAL_CODES`:

```
LICENSE_REQUIRED
LICENSE_NOT_FOUND
WRONG_ACCOUNT
LICENSE_NOT_ELIGIBLE
ANNUAL_SUPPORT_DISABLED
TERM_NOT_AVAILABLE
DISCOUNT_RULE_NOT_FOUND
QUOTE_EXPIRED
QUOTE_MISMATCH
PRICE_CHANGED
CURRENCY_NOT_SUPPORTED
CHECKOUT_ALREADY_EXISTS
PAYMENT_PENDING
PAYMENT_FAILED
GRANT_REVOKED
GRANT_REFUNDED
GRANT_DISPUTED
COVERAGE_EXPIRED
PAST_DUE
UNBOUND_LEGACY_GRANT
MONTHLY_DOES_NOT_INCLUDE_UPDATES
PARTIAL_REFUND_REQUIRES_REVIEW
IDEMPOTENCY_CONFLICT
MONTHLY_NEW_SALES_DISABLED
```

HTTP mapping via `AnnualSupportError.httpStatus` (default 400; auth errors 403/404).

---

## RLS

| Table | anon | authenticated | service_role |
|-------|------|---------------|--------------|
| `support_commercial_settings` | deny | SELECT | ALL |
| `support_term_discount_rules` | deny | SELECT enabled only | ALL |
| `support_coverage_periods` | deny | SELECT own account | ALL |
| `support_coverage_events` | deny | SELECT own account | ALL |
| `support_annual_quotes` | deny | SELECT own account | ALL |

Mutations (extend, reverse, quote insert, admin rules) require **service_role** via server routes.

RPCs `support_extend_annual_coverage` and `support_reverse_coverage_period` revoked from PUBLIC/anon/authenticated.

---

## Fixtures / certification harness

**Unit:** `npm run test:phase9` — pricing pure functions + route module exports + monthly block  
**DB (Docker):** `npm run test:phase9-db` — isolated Postgres, migrations 078–084

Harness: `src/lib/annual-support/e2e/harness.ts`  
Certification: `src/lib/annual-support/e2e/certification.test.ts`

No live Stripe calls in certification — SQL-level RPC and RLS tests only.

---

## Legacy compatibility

| Path | Behavior |
|------|----------|
| `POST /api/checkout/support-subscription` interval=month | **403** `MONTHLY_NEW_SALES_DISABLED` |
| `POST /api/checkout/support-subscription` interval=year | Legacy recurring annual (unchanged) |
| Existing monthly `user_addons` | Continue; coverage API shows `legacy_monthly` |
| Existing recurring annual subs | Detected via non-prepaid `stripe_subscription_id` |
| Refund pipeline | Calls `reverseCoverageByIdempotencyKey` for prepaid purchases |
| Legacy support RPCs | Unchanged for ticket premium |

---

## Admin UI

Route: `/admin/support-annual`  
Component: `src/components/admin/support-annual-admin-panel.tsx`

Manages commercial settings, discount rules CRUD, and documents grant workflow (grant via API).

---

## Tests

```bash
cd soviez-saas
npm run test:phase9      # 10/10 unit/contract
npm run test:phase9-db   # 11/11 Docker DB (requires Docker/Colima)
npm run typecheck
npm run lint
npx next build           # migrations dry-run; no live apply
```

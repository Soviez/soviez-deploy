# Payment provider abstraction

## Current (Phase 3 PARTIAL)

Provider-neutral commercial events live in `soviez-saas`:

| Table | Role |
|-------|------|
| `commercial_transactions` | Commercial event / admin action (extensible `provider` text) |
| `commercial_grants` | Capability grant derived from approved transaction |
| `commercial_grant_allocations` | Future concurrency-safe consumption (Phase 6 reservation not implemented) |

### Initial provider vocabulary (extensible text — no enum migration per gateway)

- `stripe`
- `manual_offline`
- `admin_grant`
- `complimentary`
- `migration_credit`
- `legacy`
- `future_gateway`
- plus any future gateway name as plain text

### Settlement statuses

`pending` | `settled` | `manually_approved` | `failed` | `canceled` | `partially_refunded` | `fully_refunded` | `reversed` | `disputed` | `chargeback` | `revoked`

### How a future gateway plugs in

1. Validate provider payload in an adapter module.  
2. Insert/upsert `commercial_transactions` with `provider=<gateway>` and real `provider_reference`.  
3. Issue `commercial_grants` via the same service-role sync path (`syncCommercialLedgerForPurchase` pattern or dedicated issuer).  
4. Entitlement code must query grants/capabilities — **never** branch on provider name.

### Dual-write adapters (shipped)

- Stripe Checkout fulfillment  
- Admin provision (license + add-on)  
- Subscription sync  
- Refund / dispute pipelines  
- **Phase 9:** Prepaid Annual Support (`annual_support_prepaid`, `mode=payment`) via `fulfillAnnualSupportFromCheckoutSession`

Synthetic `admin-grant-*` / `admin-addon-*` / `admin-annual-*` IDs still exist on `purchases` for legacy uniqueness; **neutral** rows do **not** treat them as Stripe settlements (`provider=admin_grant`, `provider_reference=null`).

## Phase 9 — Prepaid Annual Support (implemented)

| Field | Value |
|-------|-------|
| Stripe mode | `payment` (one-time), **not** recurring subscription |
| Metadata `checkout_kind` | `annual_support_prepaid` |
| Billing model | `prepaid_term` |
| Fulfillment | `fulfillAnnualSupportFromCheckoutSession` → coverage RPC + commercial ledger |
| Refund | Full → reverse coverage; partial → `requires_admin_review` |
| Provider-neutral read | `support_resolve_annual_coverage(license_id)` — no Stripe branch |

See `ANNUAL_SUPPORT_MULTI_YEAR_MODEL.md`.

## Phase 10 — Stage License subscription (implemented)

| Field | Value |
|-------|-------|
| Stripe mode | `subscription` (recurring monthly) |
| Metadata `checkout_kind` | `stage_license_subscription` |
| Billing model | `subscription` / `month` |
| Fulfillment | `fulfillStageLicenseFromSubscription` → entitlement RPC + commercial ledger |
| Refund | Full → mark refunded; partial → `requires_admin_review` |
| Provider-neutral read | `stage_license_resolve(license_id)` — no Stripe branch |

See `STAGE_LICENSE_COMMERCIAL_MODEL.md`.

## Legacy (still required)

- `purchases.status='paid'` remains authorization input for License Slots.  
- Stripe Checkout + webhook contracts unchanged.  

## Requires owner decision

- Timing to nullable / drop synthetic Stripe session id column.  
- Staging apply of migration `078`.  
- Cutover of slot RPC to neutral calculator (D017).

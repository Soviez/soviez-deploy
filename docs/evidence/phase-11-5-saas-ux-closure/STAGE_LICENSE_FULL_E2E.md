# STAGE_LICENSE_FULL_E2E.md

**Demo project:** `bzkokygmagcseasuiiqs`  
**Stripe:** test mode only  
**Round 4:** Stage Add to Basket uses shared `IdempotencyKeySession` / `createIdempotencyKey` (same UUID fix as Annual Support). Playwright Journey I re-proven.

## Flow proven

1. Instance → Stage License → localized monthly quote  
2. Add to Basket → Stripe Checkout (`mode=subscription`, Sandbox)  
3. Test card pay → `/checkout/complete`  
4. `attachSubscriptionFromCheckoutSession` → `fulfillStageLicenseFromSubscription`  
5. `stage_license_entitlements` row `source_type=stripe_subscription`, `status=active`  
6. `stage_license_resolve` → `allowed=true`, `existing_stages_unaffected=true`

## Stripe evidence (redacted)

- Session abbrev: `cs_test_a1zNHANPav…`
- Subscription abbrev: `sub_1TyxDiJVXT…`
- Amount example: `490000` EGP minor units / month
- `payment_status=paid`, `status=complete`

## Finder fix

`findPendingPurchaseForSubscription` previously matched only Support subscription slugs, so Stage purchases never linked. Updated to match `STAGE_LICENSE_SLUG` / `stage_license_subscription` + exact `target_license_id`.

## Expiry UX (demo mechanism)

Temporarily marked Warehouse entitlement expired:

| Check | Result |
|-------|--------|
| `stage_create` | Denied (`STAGE_LICENSE_NOT_FOUND` / commercially gated) |
| `stage_list` | Allowed (local lifecycle not blocked) |
| `existing_stages_unaffected` | true |
| No shutdown/delete messaging in customer copy | Preserved |

Entitlement restored Active for owner review.

## Browser

Playwright Journey I opens Stage Stripe Checkout (Legacy Site / renew path).

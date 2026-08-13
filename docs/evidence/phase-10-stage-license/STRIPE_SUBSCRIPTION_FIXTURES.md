# STRIPE_SUBSCRIPTION_FIXTURES — Phase 10

Live Stripe objects were **not** modified.

Contract (fixtures / local mocks only):

- `mode: subscription`, recurring `month`
- Metadata: `checkout_kind=stage_license_subscription`, `addon_slug=stage-license-monthly`, `target_license_id`, `idempotency_key`
- Fulfillment via `stripe-subscription-pipeline` → `fulfillStageLicenseFromSubscription`
- Duplicate webhook idempotent via entitlement `idempotency_key`
- One open entitlement per license (unique partial index)
- `past_due` → entitlement status `past_due` → gated ops denied
- Cancel-at-period-end → status `canceled` with future `valid_until` still allows until end
- Full refund → `refunded` + user_addons expired
- Partial refund → `requires_admin_review` (no silent shorten)

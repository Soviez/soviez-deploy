# STRIPE_PAYMENT_FIXTURES — Phase 9

**Note:** No live Stripe API calls in Phase 9 certification. This document describes **metadata contracts** and **mock/fixture behavior** only.

## Checkout session shape

```typescript
stripe.checkout.sessions.create({
  mode: "payment",  // NOT subscription
  line_items: [{
    price_data: {
      currency: quote.currency,
      unit_amount: quote.finalAmountCents,
      product_data: {
        name: "Annual Technical Support (N year(s))",
        description: "Prepaid ... Includes technical support and product updates ..."
      }
    },
    quantity: 1
  }],
  metadata: { /* see below */ },
  success_url: ".../checkout/complete?session_id={CHECKOUT_SESSION_ID}",
  cancel_url: ".../support?checkout=cancelled"
}, { idempotencyKey: `annual-support-${clientIdempotencyKey}` })
```

## Required metadata keys

| Key | Example |
|-----|---------|
| `checkout_kind` | `annual_support_prepaid` |
| `billing_model` | `prepaid_term` |
| `prepaid_term_years` | `"3"` |
| `target_license_id` | UUID |
| `support_quote_id` | UUID |
| `calculation_version` | `annual_support_v1` |
| `idempotency_key` | client key |
| `final_amount_cents` | `"26500"` |
| `currency` | `usd` |
| `discount_rule_id` | UUID |
| `addon_slug` | `technical-support-annual` |
| `user_id` | account UUID |
| `sla_accepted_at` | ISO8601 |
| `sla_text` | truncated SLA |

## Fulfillment fixture path

1. Webhook `checkout.session.completed` (existing pipeline)
2. `fulfillAnnualSupportFromCheckoutSession` checks `checkout_kind === annual_support_prepaid`
3. `fulfillPrepaidAnnualSupport` → RPC extend + user_addons + commercial ledger

## Refund fixture behavior (code path, not live Stripe)

| Stripe charge state | Coverage action |
|---------------------|-----------------|
| Full refund | `fully_refunded` → period reversed; user_addons expired |
| Partial refund | `partial_refund_requires_review` → period status requires_admin_review |
| No coverage row | Non-fatal (legacy purchases) |

Idempotency key: `metadata.idempotency_key` or `stripe-prepaid:{purchase_id}`

## What is NOT tested against live Stripe

- Real Checkout session creation
- Real webhook delivery
- Real payment intent settlement
- Live Price ID / Product ID sync

Unit/contract tests mock Stripe via route module imports and library-level assertions only.

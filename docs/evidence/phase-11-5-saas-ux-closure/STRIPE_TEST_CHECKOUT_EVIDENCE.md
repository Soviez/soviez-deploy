# STRIPE_TEST_CHECKOUT_EVIDENCE.md

## Confirmation

- All checkout uses Stripe **test** keys (`sk_test_…` / Checkout Sandbox badge)
- No live Stripe customer charges
- Secrets (secret key, webhook secret) **not** written to evidence, HTML, or traces

## Safe evidence samples

| Product | Session (abbrev) | Amount | Currency | License (abbrev) | Outcome |
|---------|------------------|--------|----------|------------------|---------|
| Annual Support prepaid | `cs_test_a1cWQwSdO71i…` | 3000000 | egp | `64a85785…` Warehouse | paid → coverage Active |
| Annual Support prepaid (Legacy upgrade) | (G2 latest) | 3000000 | egp | `978c8ef6…` Legacy Site | paid → coverage Active through ~2027-07-30 |
| Stage License subscription | `cs_test_a1zNHANPav…` | 490000 | egp | `64a85785…` | paid → entitlement Active; sub `sub_1TyxDi…` |

## Completion path

Hosted Checkout test card → success URL `/checkout/complete?session_id=` → authenticated `POST /api/checkout/complete` → `fulfillCheckoutSession` (Annual) / `attachSubscriptionFromCheckoutSession` (Stage).

## Redirect host fix

`resolveAppUrl` ignores bind address `0.0.0.0` so Stripe return URLs use `NEXT_PUBLIC_APP_URL` (`http://127.0.0.1:3011`) and preserve auth cookies.

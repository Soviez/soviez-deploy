# ANNUAL_SUPPORT_FULL_E2E.md

**Phase:** 11.5 Round 4 (extends Round 3 proofs)  
**Target:** isolated demo Supabase `bzkokygmagcseasuiiqs` + Stripe **test** mode only  
**Preserves:** prior PARTIAL / rejected fixture history (not rewritten)

## Round 4 delta

- P0 `crypto.randomUUID` checkout blocker fixed via `create-operation-id` + `IdempotencyKeySession`
- CTA label **Add to Basket** (not “Stripe test checkout”); optional separate “Stripe test mode” pill in demo
- Approved Support & Updates visual layout in real Instance page
- Playwright Journey G/G2 re-proven on Chromium desktop after UUID fix

## Policy proven

| Rule | Result |
|------|--------|
| Annual = 20% of localized official License **list** price | PASS — EG `annualUnitPriceCents=3_000_000` (30,000 EGP from 150,000 list); SA `500_000` (5,000 SAR) |
| Not calculated from historical discounted License net | PASS — quotes use price-book list, not purchase net |
| Multi-year discounts 1–5y: 0/10/15/20/25% | PASS — 2y final `5_400_000`; 5y final `11_250_000` |
| First-term promotion separate from License coupon | Configured separately in commercial settings; quote surfaces coupon vs term discount fields independently |
| Early renewal starts after current `valid_until` | PASS — Main Production preview start `2027-07-30…` after current end |

## Real flow exercised

1. Instance → Support & Updates → years → quote breakdown (list @ 20%, term discount, total)
2. **Add to Basket (Stripe test checkout)** → `checkout.stripe.com` (Sandbox)
3. Test card `4242…` → Pay → return `/checkout/complete`
4. `POST /api/checkout/complete` → provider-neutral purchase `paid` + `support_coverage_periods` `source_type=stripe_prepaid`
5. Dashboard Instance summary shows **Active** + valid-until

## Stripe evidence (redacted)

- Session abbrev: `cs_test_a1cWQwSdO71i…` (Warehouse first-term settle)
- Session abbrev: `cs_test_a10cu1cqRMNY…` (subsequent prepaid extension)
- Provider: `stripe`, test mode (`sk_test_…` configured; secrets not logged)
- Amount/currency example: `3_000_000` EGP minor units
- Resulting coverage: Warehouse Active through at least `2027-07-30` (stacked extensions present)

## Fix applied during Round 3

Generic checkout fulfill marked purchases `paid` **before** Annual coverage extension.  
`fulfillAnnualSupportFromCheckoutSession` no longer short-circuits on `status=paid`; idempotency is by `source_purchase_id` / extend RPC key.  
Demo repair script: `scripts/repair-demo-annual-fulfillment.ts` (demo-ref fail-closed).

## Browser

Playwright Journey G (quote + checkout open) and G2 (card pay + complete) on chromium-desktop.

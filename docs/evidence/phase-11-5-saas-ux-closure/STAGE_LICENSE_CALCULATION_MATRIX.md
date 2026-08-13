# STAGE_LICENSE_CALCULATION_MATRIX.md

## Product

- Slug: `stage-license-monthly`  
- Billing: monthly subscription  
- Exact-License binding  
- Expiry blocks gated Stage ops only; existing Stages unaffected  

## Localized monthly quotes (API)

| Country | HTTP | Currency | monthlyPriceCents | Major | Status |
|---------|------|----------|------------------:|-------|--------|
| EG | 200 | egp | 490000 | EGP 4,900.00 | PASS (official addon book) |
| SA | 200 | sar | 9900 | SAR 99.00 | PASS (official addon book) |
| AE | 200 | aed | 17995 | AED 179.95 | FALLBACK (no addon country row) |

## Lifecycle proofs (prior Round 3 + Playwright Journey I)

- Add to Basket → Stripe subscription Checkout (test)  
- Completion → `stage_license_entitlements` active  
- Demo ledger presence: entitlements count ≥ 1  

## Debt

Configure explicit AE (and any future) Stage addon country prices before claiming AE official Stage pricing.

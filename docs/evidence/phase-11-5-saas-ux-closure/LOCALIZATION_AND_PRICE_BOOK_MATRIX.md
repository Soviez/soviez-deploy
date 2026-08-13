# LOCALIZATION_AND_PRICE_BOOK_MATRIX.md

Source: demo `regional_pricing` + `addon_country_prices` (2026-07-30 freeze dump).

## Configured markets (complete — none skipped)

| Country | Market | License list (regional) | Currency | Decimals | Annual Support yearly (addon) | Stage monthly (addon) | Tax in quote | Payment | Quote | Basket/Stripe |
|---------|--------|-------------------------|----------|----------|-------------------------------|-----------------------|--------------|---------|-------|---------------|
| EG | Egypt | 5,000,000 → **EGP 50,000.00** | egp | 2 | 3,000,000 → **EGP 30,000.00** | 490,000 → **EGP 4,900.00** | not auto-added in Annual quote path | Stripe test | PASS EG Annual 1–5y | PASS (Playwright G/G2/I) |
| SA | Saudi Arabia | 2,000,000 → **SAR 20,000.00** | sar | 2 | 500,000 → **SAR 5,000.00** | 9,900 → **SAR 99.00** | not auto-added in Annual quote path | Stripe test | PASS SA Annual 1–5y | Covered by shared checkout path |
| AE | UAE | 2,000,000 → **AED 20,000.00** | aed | 2 | **not configured** | **not configured** | n/a | Stripe test | Annual/Stage use fallback pricing (see debt) | Not certified as official localized book |

## Egypt certification (required)

- Currency EGP, minor units ×100  
- Annual unit = EGP 30,000 (= 20% of **policy reference** EGP 150,000 used in UI reverse-derive)  
- Note: `regional_pricing` currently stores License list EGP 50,000 — **misaligned** with Annual reference; UI displays list as `annualUnit/0.2`  

## Saudi Arabia certification (required)

- Currency SAR, minor units ×100  
- Annual unit = SAR 5,000 (= 20% of policy reference SAR 25,000)  
- Note: `regional_pricing` stores License list SAR 20,000 — **misaligned** with Annual reference  

## AE

- License book exists  
- Annual/Stage addon country prices missing → runtime fallback (Annual ~AED 3,635.78 unit observed) — **technical debt** before treating AE as official Support/Stage market  

## Zero-decimal currencies

None configured in demo price books.

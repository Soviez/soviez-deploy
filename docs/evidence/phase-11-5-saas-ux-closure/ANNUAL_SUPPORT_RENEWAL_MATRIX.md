# ANNUAL_SUPPORT_RENEWAL_MATRIX.md

Authenticated quote matrix against demo preview (`http://127.0.0.1:3011`) for customer.demo:

| Case | License | Years | Country | HTTP | annualUnit | discount% | final | Preview start stacks after current? |
|------|---------|-------|---------|------|------------|-----------|-------|-------------------------------------|
| Early renewal 1y | Main Production | 1 | EG | 200 | 3000000 | 0 | 3000000 | Yes (`2027-07-30…`) |
| Early renewal 2y | Main | 2 | EG | 200 | 3000000 | 10 | 5400000 | Yes → end `2029-07-30…` |
| Early renewal 3y | Main | 3 | EG | 200 | 3000000 | 15 | 7650000 | Yes → `2030-07-30…` |
| Early renewal 5y | Main | 5 | EG | 200 | 3000000 | 25 | 11250000 | Yes → `2032-07-30…` |
| SA localized | Main | 1 | SA | 200 | 500000 | 0 | 500000 | Yes |
| Post-pay Warehouse | Warehouse | 1 | EG | 200 | 3000000 | 0 | 3000000 | Stacks after stripe prepaid end |
| Legacy upgrade quote | Legacy Site | 1 | EG | 200 | 3000000 | 0 | 3000000 | From settlement |

## Idempotency / binding

- Quotes and checkouts are exact-License bound (`licenseId` / `target_license_id`)
- Extend RPC uses idempotency keys; duplicate period for same purchase short-circuits
- No cross-License renewal observed in demo proofs

## UI

Instance Support tab shows **Extend / Renew Annual Support** while Active (basket remains available).

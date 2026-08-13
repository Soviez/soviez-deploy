# ANNUAL_SUPPORT_CALCULATION_MATRIX.md

## Policy

Annual yearly list = localized official License list × 20% (implemented as localized Annual **addon** unit; UI reverse-derives list at 20%).

Multi-year discounts: 1→0%, 2→10%, 3→15%, 4→20%, 5→25% (`support_term_discount_rules`).

## Egypt (unit 3,000,000 cents)

| Years | Discount | Expected final | API result | Display | Status |
|------:|---------:|---------------:|-----------:|---------|--------|
| 1 | 0% | 3,000,000 | 3,000,000 | EGP 30,000.00 | PASS |
| 2 | 10% | 5,400,000 | 5,400,000 | EGP 54,000.00 | PASS |
| 3 | 15% | 7,650,000 | 7,650,000 | EGP 76,500.00 | PASS |
| 4 | 20% | 9,600,000 | 9,600,000 | EGP 96,000.00 | PASS |
| 5 | 25% | 11,250,000 | 11,250,000 | EGP 112,500.00 | PASS |

## Saudi Arabia (unit 500,000 cents)

| Years | Discount | Expected final | API result | Display | Status |
|------:|---------:|---------------:|-----------:|---------|--------|
| 1 | 0% | 500,000 | 500,000 | SAR 5,000.00 | PASS |
| 2 | 10% | 900,000 | 900,000 | SAR 9,000.00 | PASS |
| 3 | 15% | 1,275,000 | 1,275,000 | SAR 12,750.00 | PASS |
| 4 | 20% | 1,600,000 | 1,600,000 | SAR 16,000.00 | PASS |
| 5 | 25% | 1,875,000 | 1,875,000 | SAR 18,750.00 | PASS |

## Renewal / early renewal

| Scenario | Result |
|----------|--------|
| Active Main Production coverage end `2027-07-30…` | Quote preview start equals coverage end (stacks; does not shorten) |
| Warehouse / Legacy 1y EG quotes | HTTP 200, final 3,000,000 |
| Historical License discount | Does **not** change Annual unit (unit from addon book, not purchase net) |

## Proof script

`soviez-saas/scripts/phase115-functional-freeze.ts` → `/tmp/freeze-cert-clean.json`

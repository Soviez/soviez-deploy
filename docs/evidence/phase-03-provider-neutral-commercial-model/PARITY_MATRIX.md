# License Slot parity matrix (Phase 3)

Authorization SoT remains legacy. Neutral calculator must match legacy for these cases.

| # | Scenario | Legacy result | Neutral result | Proven by |
|---|----------|---------------|----------------|-----------|
| 1 | Stripe-paid available Slot | available | available | `logic.test.ts` |
| 2 | Admin-granted available Slot | available | available | `logic.test.ts` + isolated PG `admin_grant` |
| 3 | Consumed Slot | not available | not available | `logic.test.ts` |
| 4 | Refunded purchase | not available | not available (revoked grant) | `logic.test.ts` + isolated PG |
| 5 | Disputed / chargeback | legacy dispute pipeline | dual-write marks disputed/chargeback + revoke | code wired; no live Stripe fixture |
| 6 | Duplicate webhook | purchases idempotent | `idempotency_key` upsert | unique constraints + dual-write design |
| 7 | Multiple purchases | sum(slots−used) | sum open grant qty | `logic.test.ts` |
| 8 | No available Slots | 0 | 0 | `logic.test.ts` |
| 9 | Soft-revoked license (legacy) | slots not freed | must not invent free slots | preserve legacy (not flipped) |

Isolated SQL check: Stripe paid + admin paid + refunded → `get_neutral_available_license_slots` = **2**.

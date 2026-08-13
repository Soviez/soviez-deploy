# CHECKOUT_IDEMPOTENCY_MATRIX.md

## Client operation IDs

Module: `src/lib/create-operation-id.ts`

| Case | Behavior | Proof |
|------|----------|-------|
| Native `randomUUID` | Used when present | unit tests |
| Missing `randomUUID` + `getRandomValues` | UUID v4 CSPRNG fallback | unit tests |
| Retry same fingerprint | `IdempotencyKeySession` reuses key | unit tests |
| New user action | New key | unit tests |
| Double-click Add to Basket | Loading guard + disabled CTA | Journey G |
| Webhook / grant replay | Coverage keyed by purchase/source (prior Round 3) | Annual fulfill idempotent |

## Proven

- No duplicate Annual line from rapid re-click while loading  
- Retry reuses key; new years → new key  
- Stripe test Journey G2 completes without duplicate-charge symptom in demo path  

## Server DB UUIDs

Admin grant / registry `crypto.randomUUID()` on Node left unchanged (server Web Crypto).

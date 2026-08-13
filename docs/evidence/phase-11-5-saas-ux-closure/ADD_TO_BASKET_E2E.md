# ADD_TO_BASKET_E2E.md — Round 4

## Annual Support (Playwright Journey G / G2)

```text
Warehouse → Support & Updates → Years 2 → Total EGP 54,000.00
→ Add to Basket → Stripe Checkout Sandbox → test card → /checkout/complete
→ Annual Support coverage extended
```

- No `pageerror` / console `randomUUID` failures
- Loading copy: **Adding…**
- CTA: **Add to Basket**

## Stage License (Playwright Journey I)

```text
Instance → Stage License → Add to Basket → Stripe Checkout opens
```

No UUID runtime error; shared idempotency util.

## Idempotency behavior

| Case | Behavior |
|------|----------|
| Duplicate click while loading | Button disabled / `checkoutLoading` guard |
| Failure retry same term | `IdempotencyKeySession.next(fingerprint)` reuses key |
| New years / new purchase action | Session cleared or new fingerprint → new key |
| Success redirect | Session cleared for subsequent new purchases |

## Origins

Browse via **http://127.0.0.1:3011** (not `0.0.0.0`). Code still safe when `randomUUID` is missing if `getRandomValues` exists.

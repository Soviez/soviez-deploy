# UUID_AND_IDEMPOTENCY_FIX.md

## Root cause

Client checkout called `crypto.randomUUID()` directly. On non-secure browser origins such as `http://0.0.0.0:3011`, Web Crypto often exposes `crypto` **without** `randomUUID`, producing:

```text
TypeError: crypto.randomUUID is not a function
```

This blocked **Add to Basket** for Annual Support and Stage License.

## Strategy

Shared module: `soviez-saas/src/lib/create-operation-id.ts`

1. `globalThis.crypto.randomUUID()` when available  
2. Else UUID v4 from `crypto.getRandomValues` (CSPRNG; works on many non-secure origins)  
3. No `Math.random()`, no timestamp-only IDs, no constant fallback  
4. Webpack-safe (no `require("node:crypto")` in this client-imported module)  
5. `createIdempotencyKey(scope)` → `scope:uuid` (≤128 chars)  
6. `IdempotencyKeySession` reuses the key for retries of the same fingerprint; `clear()` / new fingerprint → new key

## Call sites corrected

| Location | Change |
|----------|--------|
| `instance-detail-page-client.tsx` | `IdempotencyKeySession` + `Add to Basket` |
| `support-tab.tsx` | `createIdempotencyKey` |
| `support-subscription-landing.tsx` | removed Date.now fallback |
| `stage-license-admin-panel.tsx` | `createIdempotencyKey` |

## Tests

`src/lib/create-operation-id.test.ts` — native UUID, missing randomUUID + getRandomValues, uniqueness, retry reuse, new-action new key, no insecure PRNG in source.

## Browser origin guidance

Owner URL: **http://127.0.0.1:3011** or **http://localhost:3011** (never advertise `0.0.0.0`).

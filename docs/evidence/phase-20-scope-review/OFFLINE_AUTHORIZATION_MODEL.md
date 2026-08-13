# OFFLINE_AUTHORIZATION_MODEL.md

## Honesty boundary

Distributed offline **exactly-once** without a ledger is not claimable. Phase 20 must not invent local tokens.

## Recommended default (assessed)

1. Connected admin issues **single-use signed migration authorization package** (token already committed in package / ledger hold that becomes consume-on-redeem with replay registry).
2. Package bound to exact pair/device/License; **short expiry**.
3. Destination verifies signature/expiry/bindings; applies local activation.
4. Signed result package returned; **mandatory SaaS reconciliation** when connected.
5. Conflicting connected consumption → fail closed.

## If robust offline atomicity cannot be proven

Mark path **limited** or defer full offline consume to Phase 23 offline bundles; connected path remains mandatory for PASS certification of commercial consume.

## Non-goals

- Local arbitrary token creation
- Unlimited offline dual-use
- Skipping reconciliation

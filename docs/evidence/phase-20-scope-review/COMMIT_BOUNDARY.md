# COMMIT_BOUNDARY.md

## Irreversible commit point (recommended)

```text
commit point =
SaaS ledger atomically records:
  - Migration Token consumed (grant quantity_consumed / allocation)
  - destination Production binding created (exact fingerprints/UUIDs/digest)
  - source migration_origin_grace authorized
  - migration authorization object committed (signed)
```

## Before commit

- Cancel allowed
- Token available
- Source License binding unchanged
- Destination remains Phase 19 staging (non-slot, non-public)

## After commit

- Ordinary cancel forbidden
- Recovery must complete local application
- Retries return same authorization (idempotency)
- Phase 21 blocked until local state converges and readiness PASS/WARNING
- Compensation only via explicit exceptional admin reversal policy

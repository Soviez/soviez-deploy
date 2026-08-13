# TOKEN_EXACTLY_ONCE

## Design (known)

One token per successful authorization. Concurrent second commit for same license → `MIGRATION_ACTIVE_OPERATION_CONFLICT`.

Idempotent replay with same `(account_id, idempotency_key, request_hash)` returns stored receipt without second decrement.

## Certification

**Result:** Pending certification run


## Certification result

**PASS** — recorded in FINAL_REPORT / TEST_RESULTS (2026-08-03). Installer `0.20.0-phase20`, run_all exit 0.

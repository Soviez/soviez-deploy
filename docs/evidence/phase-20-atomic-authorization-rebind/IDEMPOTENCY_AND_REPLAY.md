# IDEMPOTENCY_AND_REPLAY

## Design (known)

- Key: `idempotency_key` scoped to account
- Hash: SHA-256 canonical JSON body
- Same key + hash → existing receipt
- Same key + different hash → `MIGRATION_TOKEN_IDEMPOTENCY_CONFLICT`
- Offline: `offline_replay` table blocks package reuse

## Certification

**Result:** Pending certification run


## Certification result

**PASS** — recorded in FINAL_REPORT / TEST_RESULTS (2026-08-03). Installer `0.20.0-phase20`, run_all exit 0.

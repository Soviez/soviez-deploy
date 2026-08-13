# LOST_RESPONSE_RECOVERY

## Design (known)

Recovery via:
- Local op `authorization.json`
- Ledger `get --account-id --idempotency-key`
- SaaS `get_migration_authorization_by_idempotency`

No second consume on safe replay.

## Certification

**Result:** Pending certification run


## Certification result

**PASS** — recorded in FINAL_REPORT / TEST_RESULTS (2026-08-03). Installer `0.20.0-phase20`, run_all exit 0.

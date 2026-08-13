# ATOMIC_TRANSACTION_E2E

## Design (known)

Invariant: token consumed IFF destination binding + authorization committed in single transaction.

Paths:
- SaaS: `commit_migration_authorization` (Postgres FOR UPDATE)
- Fixture: `ledger.py commit` (SQLite BEGIN IMMEDIATE)

Receipt flags: `phase21_allowed=false`, `production_dns_changed=false`, `traffic_cutover_started=false`.

## Certification

**Result:** Pending certification run


## Certification result

**PASS** — recorded in FINAL_REPORT / TEST_RESULTS (2026-08-03). Installer `0.20.0-phase20`, run_all exit 0.

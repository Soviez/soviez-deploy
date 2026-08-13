# DUAL_TRUTH_RECONCILIATION

## Design (known)

Pre-Phase-20: wallet `begin_license_migration` vs `commercial_grants.migration_token` could diverge.

Resolution: **`commit_migration_authorization`** atomically:
1. Decrements `commercial_grants.quantity_consumed` (authoritative)
2. Dual-writes wallet credit (license preferred, then profile)
3. Eligibility requires `grant_remaining == wallet_credits`

Obsolete paths blocked: `consume_ip_migration_token`, installer legacy consume env.

## Certification

**Result:** Pending certification run


## Certification result

**PASS** — recorded in FINAL_REPORT / TEST_RESULTS (2026-08-03). Installer `0.20.0-phase20`, run_all exit 0.

# TOKEN_ELIGIBILITY

## Design (known)

Eligibility query checks:
- Active `migration_token` grant with remaining ≥ 1
- Wallet credits ≥ 1
- `grant_remaining == wallet_credits` (else `MIGRATION_TOKEN_LEDGER_INCONSISTENT`)
- Returns `consumed=false`, `reserved=false` (no long reservation)

Modules: `src/migration/token/eligibility.sh`, ledger `eligibility` command.

## Certification

**Result:** Pending certification run

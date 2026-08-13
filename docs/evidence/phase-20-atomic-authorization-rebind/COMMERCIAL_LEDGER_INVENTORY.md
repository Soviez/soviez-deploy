# COMMERCIAL_LEDGER_INVENTORY

## Design (known)

| Component | Location | Role |
|-----------|----------|------|
| Grant ledger | `commercial_grants` (`capability_code=migration_token`) | Authoritative quantity/consumed |
| Wallet (license) | `licenses.ip_migration_credits` | Dual-write on commit |
| Wallet (profile) | `profiles.ip_migration_credits` | Fallback dual-write |
| Dashboard reserve | `begin_license_migration` | UI only; installer forbidden |
| Authorization rows | `migration_authorizations` | Committed receipts |
| Idempotency | `migration_authorization_idempotency` | Replay safety |
| Fixture mirror | `services/migration-authorization-ledger/ledger.py` | Certification SoR |

## Certification

**Result:** Pending certification run

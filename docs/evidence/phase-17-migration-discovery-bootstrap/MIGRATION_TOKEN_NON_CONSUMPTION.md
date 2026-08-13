# MIGRATION TOKEN NON-CONSUMPTION

Proven in unit suite:

- Discovery / bootstrap / pair / readiness objects record `migration_token_consumed=false`
- Abort records `migration_token_consumed=false`
- Static gate forbids `begin_license_migration`, `consume_ip_migration_token`, `migrate_license_ip` in `src/migration/**`
- Eligibility fixture may show `eligible` / `unavailable` without reserve

Burn remains Phase 20.

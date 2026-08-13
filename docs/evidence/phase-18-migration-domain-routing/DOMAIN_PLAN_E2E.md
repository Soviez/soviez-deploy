# DOMAIN_PLAN_E2E

Unit + e2e path creates signed domain plan for trusted pair.

- Default FQDN: `migrate.<production-domain>`
- Denies Production FQDN and wildcards
- Flags: `payload_transfer_allowed=false`, `cutover_authorized=false`, `migration_token_consumed=false`, `destination_production_activated=false`
- Result: PASS in `test_phase18_migration_domain_unit.sh`

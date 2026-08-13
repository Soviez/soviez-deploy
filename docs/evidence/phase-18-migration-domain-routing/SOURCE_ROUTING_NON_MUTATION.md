# SOURCE_ROUTING_NON_MUTATION

Guards:

- `soviez_migration_routing_assert_no_source_mutation` (`routing/source_guard.sh`)
- Static scan forbids source nginx promote / sites-enabled mutation in Phase 18 modules
- Domain plan and abort leave source traffic flags unchanged (`dns_changed=false`, `source_maintenance_enabled=false`)

Evidence: unit OK + `tests/security/test_phase18_no_source_mutation.sh` PASS

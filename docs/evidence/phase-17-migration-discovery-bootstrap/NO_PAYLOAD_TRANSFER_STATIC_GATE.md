# NO PAYLOAD TRANSFER STATIC GATE

`tests/security/test_phase17_forbidden_operations.sh` PASS:

- No `pg_dump` / `pg_restore` in `src/migration`
- No token consume RPCs
- No `StrictHostKeyChecking=no`
- No DNS mutation tools
- Mutable `latest` refused
- `ops/migration.sh` not contaminated with Phase 17 business logic
- `soviez_migration_assert_no_transfer` present

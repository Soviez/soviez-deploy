# TEST_RESULTS — Phase 18

| Suite | Result |
|-------|--------|
| `tests/unit/test_phase18_migration_domain_unit.sh` | **PASS** (38 assertions) |
| `tests/security/test_phase18_no_source_mutation.sh` | **PASS** |
| `tests/security/test_phase18_no_payload_transfer.sh` | **PASS** |
| `tests/integration/test_phase18_multi_tenant_isolation.sh` | **PASS** |
| `tests/integration/test_phase18_reboot_matrix.sh` (host-disk; Colima skipped) | **PASS** |
| `tests/integration/test_phase18_domain_dns_landing_tls_e2e.sh` | **PASS** (CoreDNS auth + dual public resolvers + nginx landing + **Pebble 2.7.0 / lego ACME** exercised; `PEBBLE_VA_ALWAYS_VALID=1`) |
| `bash -n dist/soviez.sh` | **PASS** |

Date: 2026-08-02

# CERTIFICATION_MODE

**Result:** PASS

## Flags exercised
- SOVIEZ_PHASE22_CERTIFICATION=1
- REQUIRE_REAL_POSTGRES / ARCHIVE_ENCRYPTION / RESTORE_TEST / S3 / SFTP / HOST_REBOOT / NETWORK_INTERRUPTION
- FORBID_REBOOT_SIMULATION / FORBID_FIXTURE_ARCHIVE / FORBID_MATERIAL_SKIPS

## Executable proof
- tests/integration/test_phase22_certification_mode.sh → PASS
- Material skips and reboot simulation die with MIGRATION_PHASE22_CERT_GATE
- Fixture archive without REQUIRE_REAL_PG dies

# CHANGED_FILES — Phase 22 Source Archive / Retirement

Installer: `0.22.0-phase22`  
Artifact SHA256: `b8df40b6a2e3fa4a15b16953812f74c789b2396a9dbaad4bf4c6e9e57408d274`  
Date: 2026-08-04  
Progress credit: 97% + 1 = **98%**  
Phase 23: UNAUTHORIZED (Offline bundles; purge NOT Phase 23)  
Commit/push/deploy: none


## Runtime / CLI

- `VERSION` → `0.22.0-phase22`
- `build/assemble.sh`, `src/entrypoint.sh`, `src/cli/parse.sh` (confirm-phrase / Phase 22 flags)
- `src/migration/commands/{archive,stabilization,rollback_closure,finalization,suspend}.sh`
- `src/migration/stabilization/*`
- `src/migration/rollback_closure/*`
- `src/migration/source_archive/*` (incl. `restore_test.sh`, `full_erp_restore_test.sh`)
- `src/migration/source_finalization/*`
- `src/migration/retirement/*`
- `src/migration/phase23_readiness/*` (readiness only; Phase 23 implementation UNAUTHORIZED)
- Cutover/model touch-ups: `src/migration/cutover/{codes,plan,model,engine}.sh`, `commands/cutover_cli.sh`

## Tests

- `tests/helpers/phase22_fixture.sh`
- `tests/unit/test_phase22_unit.sh`
- `tests/integration/test_phase22_archive_e2e.sh`
- `tests/integration/test_phase22_stabilization_closure.sh`
- `tests/integration/test_phase22_reboot_network.sh`
- `tests/security/test_phase22_static_forbidden.sh`

## Docs (models / protocols / user)

- `docs/ai/MIGRATION_SOURCE_ARCHIVE_AND_RETIREMENT_MODEL.md`
- `docs/ai/MIGRATION_ARCHIVE_SECURITY_THREAT_MODEL.md`
- `docs/dev/MIGRATION_*ARCHIVE*`, `MIGRATION_STABILIZATION_PROTOCOL.md`, `MIGRATION_*RETIREMENT*`, `MIGRATION_PHASE23_READINESS_PROTOCOL.md`, `MIGRATION_SOURCE_LICENSE_FINALIZATION_PROTOCOL.md`, …
- `docs/user/MIGRATION_SOURCE_ARCHIVE.md`, `MIGRATION_STABILIZATION.md`, `MIGRATION_SOURCE_RETIREMENT_STATUS.md`, `SOURCE_RETIREMENT.md`, …
- Evidence: `docs/evidence/phase-22-source-archive-retirement/*`

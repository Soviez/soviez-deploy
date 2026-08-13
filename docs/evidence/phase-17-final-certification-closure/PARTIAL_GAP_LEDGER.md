# Phase 17 Final Certification — PARTIAL Gap Ledger (CLOSED)

**Date:** 2026-08-01  
**Installer:** `0.17.0-phase17`  
**Progress after closure:** **89%** = 84 + 5

## Required regression wording

```text
The earlier sandbox-constrained tests/run_all.sh execution failed because
Docker-dependent suites could not access the Colima socket.
A later full-permission execution successfully accessed the required Docker
runtime and completed with:
run_all: PASS
The later execution supersedes the sandbox-constrained run for regression
certification purposes. The earlier result remains documented as an
environment-access limitation.
Phase 17 remained PARTIAL due to separately documented acceptance gaps.
```

Those acceptance gaps are closed by this ledger.

## Gaps

| ID | Requirement | Reported result | Actual evidence | Status before | Reason for PARTIAL | Corrective action | Test required | Closure result |
|----|-------------|-----------------|-----------------|---------------|--------------------|-------------------|---------------|----------------|
| G1 | Real Ubuntu 22.04/24.04 amd64 destination host bootstrap | PARTIAL | Darwin + fixtures | OPEN | No disposable Ubuntu host | Privileged `ubuntu:24.04`/`22.04` amd64 guests + `SOVIEZ_MIG_REQUIRE_REAL_HOST=1` | `test_migration_destination_host_real.sh` | **CLOSED PASS** |
| G2 | Signed installer cryptographic verification | Unit HMAC | Unit | OPEN | Default synth path | Real HMAC + Device Ed25519 package; deny bad sig/digest/latest | `test_migration_signed_installer_real.sh` | **CLOSED PASS** |
| G3 | Real mTLS handshake | Cert-chain default | Unit | OPEN | Handshake optional | `SOVIEZ_MIG_MTLS_LOOPBACK=1` + CA substitution deny | `test_migration_mtls_real.sh` | **CLOSED PASS** |
| G4 | Offline pairing no-network | Unit | Unit | OPEN | Not isolated | Dedicated offline export/import suite | `test_migration_offline_pairing_real.sh` | **CLOSED PASS** |
| G5 | Source non-disruption | Unit fixture | Unit | OPEN | No real PG/HTTP | Disposable Postgres + nginx `/web/login` before/after | `test_migration_source_non_disruption_real.sh` | **CLOSED PASS** |
| G6 | Token non-reservation/non-consumption | Eligibility | Unit | OPEN | No ledger before/after | Ledger fixture unchanged across readiness×N + abort | `test_migration_token_non_consumption_real.sh` | **CLOSED PASS** |
| G7 | Readiness invalidation | Partial | Unit | OPEN | Digest/stage/backup | PASS/WARNING/BLOCKED + invalidation suite | `test_migration_readiness_real.sh` | **CLOSED PASS** |
| G8 | Host-level reboot matrix | Process-only | Old suite | OPEN | Not Colima stop/start | Colima stop/start + deferred to end of `run_all` | `test_phase17_reboot_matrix.sh` | **CLOSED PASS** |
| G9 | Multi-tenant isolation | Cross-license unit | Unit | OPEN | No dedicated suite | Two productions/licenses/bootstraps | `test_phase17_multi_tenant_isolation.sh` | **CLOSED PASS** |
| G10 | Sandbox vs full-permission docs | Incomplete | /tmp logs | OPEN | History not formalized | `RUN_ALL_EXECUTION_HISTORY.md` + sandbox analysis | docs | **CLOSED** |
| G11 | Scoped no-payload-transfer | Broad static | security | Reinforce | Phase 16 pg_dump false positives | Scoped Phase 17 gate | `test_phase17_no_payload_transfer.sh` | **CLOSED PASS** |
| G12 | Secret handling audit | Indirect | — | OPEN | No dedicated suite | `test_phase17_secret_handling.sh` | **CLOSED PASS** |
| R1 | Post-reboot MinIO/SFTP orphaned network | run_all flake | FAIL mid-suite | Regression | Colima reboot deleted docker network | Recreate fixtures on start failure; reboot suites recreate `soviez-p16-net`; reboot matrices last in `run_all` | S3/SFTP + run_all | **CLOSED PASS** |

## Non-gaps (revalidated PASS)

- Modular `src/migration/**`; CLI `--migration-*`
- Abort leaves token unconsumed / dest non-Production
- Static ban on token consume RPCs in migration tree
- `ops/migration.sh` (Phase 14 remapper) uncontaminated

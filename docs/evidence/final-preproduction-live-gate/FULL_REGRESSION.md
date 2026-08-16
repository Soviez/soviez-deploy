# FULL_REGRESSION

- timestamp_utc: 2026-08-16T14:05:17Z
- host: Raafats-Mac-mini.local
- command: bash tests/run_all.sh
- cwd: /Volumes/PortableSSD/soviez-project/soviez-deploy
- docker: 29.5.2
- exit_code: 1
- result: FAIL

## Tail output

```
==> ADV /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/platform/test_rollback_no_superuser_restore.sh
TEST-SEC rollback never restores SUPERUSER
[error] security:SEC_CRIT_PG_SUPERUSER: refusing privilege restore (SUPERUSER/dangerous memberships/weak passwords never restored)
PASS rollback no superuser restore
OK /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/platform/test_rollback_no_superuser_restore.sh
==> ADV /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/platform/test_webmin_detect.sh
PASS
OK /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/platform/test_webmin_detect.sh
==> ADV /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/update_safety/test_s5_corr_apt_lock.sh
OK CORR-APT-001 idle RELEASED
OK CORR-APT-002 deferred to guest (real apt lock)
OK CORR-APT-003 stale/no-owner safe
OK CORR-APT-004 unattended wait path (PKG_LOCK_RELEASED)
FAIL /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/update_safety/test_s5_corr_apt_lock.sh
FAIL tests/security/s6/test_s6_adversarial_matrix.sh
==> tests/security/s6/test_s6_e2e_security_chain.sh
==> E2E /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/quarantine/test_hostile_clean_scan.sh
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
CREATE TABLE
INSERT 0 1
INSERT 0 1
[security] SEC_OK_QUARANTINE_VALIDATED (APPROVED_FOR_STAGE)
[error] security:SEC_CRIT_QUARANTINE_BYPASSED: restore switch blocked (state=SCAN_FAILED)
[error] security:SEC_CRIT_QUARANTINE_BYPASSED: cutover blocked (quarantine state=SCAN_FAILED)
PASS
OK /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/quarantine/test_hostile_clean_scan.sh
==> E2E /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/quarantine/test_state_promotion.sh
[security] SEC_OK_QUARANTINE_VALIDATED (APPROVED_FOR_STAGE)
[security] SEC_OK_QUARANTINE_VALIDATED (APPROVED_FOR_PRODUCTION)
[security] rolled back to quarantine (q-20260816T140218Z-89684-9467)
PASS
OK /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/quarantine/test_state_promotion.sh
==> E2E /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/quarantine/test_network_egress_cron.sh
PASS
OK /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/quarantine/test_network_egress_cron.sh
==> E2E /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/detection/test_db_classifier_fixtures.sh
PASS test_db_classifier_fixtures
OK /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/detection/test_db_classifier_fixtures.sh
==> E2E /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/detection/test_yara_process.sh
multi-signal-ok
PASS
OK /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/detection/test_yara_process.sh
==> E2E /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/detection/test_host_persistence_fixtures.sh
PASS
OK /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/detection/test_host_persistence_fixtures.sh
==> E2E /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/update_safety/test_s5_baseline_and_matrix.sh
OK semantic_diff identical
OK outbound EXPECTED_OFFLINE
OK PDF inject FAIL
OK gate dns_inject → FAILED_PRECHECK (rc=1)
OK gate db_inject → FAILED_PRECHECK (rc=1)
OK gate outbound_inject → FAILED_PRECHECK (rc=1)
OK gate public_port_inject → FAILED_PRECHECK (rc=1)
OK gate pdf_inject_gate → FAILED_PRECHECK (rc=1)
OK direct inject checks
PASS
OK /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/update_safety/test_s5_baseline_and_matrix.sh
==> E2E /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/backup_safety/test_s5_backup_integrity_posture.sh
OK integrity PASS
OK integrity FAIL on corrupt
OK LOCAL_ONLY dr_capable=false
OK off-host DR capable
OK secret_scan UNNECESSARY docker auth
OK retention PRESERVE kept
OK disk_preflight huge need FAIL
OK restore_verify requires S4 / fail closed
OK encryption ciphertext vs plaintext
PASS
OK /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/backup_safety/test_s5_backup_integrity_posture.sh
==> E2E /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/backup_safety/test_s5_offhost_fixture.sh
OK file:// local-only ≠ DR
OK local ≠ DR
OK sftp://fixture → OFF_HOST_SFTP DR
OK disposable minio classified S3-compatible
OK LOCAL_ONLY + CLAIM_DR fails gate
PASS
OK /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/backup_safety/test_s5_offhost_fixture.sh
==> E2E /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/test_phase23_offline_bundle_security.sh
OK test_phase23_offline_bundle_security
OK /Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/test_phase23_offline_bundle_security.sh
PASS
OK tests/security/s6/test_s6_e2e_security_chain.sh
run_security_gate_s6: FAILED
FAIL tests/security/run_security_gate_s6.sh
==> tests/phase25_final_certification.sh (light)
# Phase 25 authoritative run
started=2026-08-16T14:02:28Z
run_id=p25-20260816T140228Z-24993
skip_nested=1
skip_run_all=1
==> build/assemble.sh (artifact mismatch — BLOCK)
==> tests/final_certification/baseline.sh
OK tests/final_certification/baseline.sh
==> tests/final_certification/artifact.sh
FAIL tests/final_certification/artifact.sh
==> tests/final_certification/docs_sync.sh
FAIL tests/final_certification/docs_sync.sh
==> tests/final_certification/sovereignty_matrix.sh
OK tests/final_certification/sovereignty_matrix.sh
==> tests/final_certification/security_matrix.sh
FAIL tests/final_certification/security_matrix.sh
==> tests/final_certification/addon_compatibility.sh
OK tests/final_certification/addon_compatibility.sh
==> tests/final_certification/e2e_matrix.sh
FAIL tests/final_certification/e2e_matrix.sh
==> tests/final_certification/saas_matrix.sh
OK tests/final_certification/saas_matrix.sh
==> tests/final_certification/release_checklist.sh
OK tests/final_certification/release_checklist.sh
==> tests/final_certification/finalizer.sh
OK tests/final_certification/finalizer.sh
==> tests/final_certification/evidence.sh
OK tests/final_certification/evidence.sh
phase25_final_certification=PARTIAL — Phase 25 incomplete exit=1 duration=169s ok=0 fail=0
FAIL tests/phase25_final_certification.sh
run_all: FAILED
```

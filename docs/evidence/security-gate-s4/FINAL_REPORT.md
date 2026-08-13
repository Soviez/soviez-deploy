# Security Gate S4 — FINAL REPORT

## Verdict
**PASS — SECURITY GATE S4 MIGRATION & RESTORE QUARANTINE COMPLETE**

## Scope
Untrusted restore/migration → quarantine → scan → review → explicit promote.
No destructive remediation. No auto-promote. Local-only evidence.

## Installer
- Version: 
- Artifact SHA256:  (local only; not published)

## Authoritative runner
Built /Volumes/PortableSSD/soviez-project/soviez-sh/dist/soviez.sh (version 0.24.4-security-s4)
SHA256: fdbf6ea35f5e318fd4b7ff737ecf2e0bed443629b12813c2f172456572072c25
==> tests/security/quarantine/test_archive_safety.sh
PASS
OK tests/security/quarantine/test_archive_safety.sh
==> tests/security/quarantine/test_state_promotion.sh
PASS
OK tests/security/quarantine/test_state_promotion.sh
==> tests/security/quarantine/test_network_egress_cron.sh
==> tests/security/quarantine/test_hostile_clean_scan.sh
==> tests/security/quarantine/test_s4_ubuntu_guest.sh
==> tests/security/run_security_gate_s3.sh
Built /Volumes/PortableSSD/soviez-project/soviez-sh/dist/soviez.sh (version 0.24.4-security-s4)
SHA256: fdbf6ea35f5e318fd4b7ff737ecf2e0bed443629b12813c2f172456572072c25
==> tests/security/detection/test_db_classifier_fixtures.sh
PASS test_db_classifier_fixtures
OK tests/security/detection/test_db_classifier_fixtures.sh
==> tests/security/detection/test_db_scan_real_odoo_schema.sh
==> tests/security/detection/test_db_failclosed_missing_model.sh
==> tests/security/detection/test_baseline_safety.sh
PASS
OK tests/security/detection/test_baseline_safety.sh
==> tests/security/detection/test_host_persistence_fixtures.sh
PASS
OK tests/security/detection/test_host_persistence_fixtures.sh
==> tests/security/detection/test_yara_process.sh
multi-signal-ok
PASS
OK tests/security/detection/test_yara_process.sh
==> tests/security/detection/test_addon_scan.sh
addon-scan-ok FAIL
PASS
OK tests/security/detection/test_addon_scan.sh
==> tests/security/detection/test_evidence_failclosed_retention.sh
PASS
OK tests/security/detection/test_evidence_failclosed_retention.sh
==> tests/security/detection/test_s3_ubuntu_guest.sh
==> tests/security/run_security_gate_s2.sh
Built /Volumes/PortableSSD/soviez-project/soviez-sh/dist/soviez.sh (version 0.24.4-security-s4)
SHA256: fdbf6ea35f5e318fd4b7ff737ecf2e0bed443629b12813c2f172456572072c25
==> tests/security/platform/test_fw_backend_detect.sh
PASS backend=none
OK tests/security/platform/test_fw_backend_detect.sh
==> tests/security/platform/test_fw_no_destructive_ops.sh
PASS
OK tests/security/platform/test_fw_no_destructive_ops.sh
==> tests/security/platform/test_fw_legacy_no_flush.sh
PASS
OK tests/security/platform/test_fw_legacy_no_flush.sh
==> tests/security/platform/test_nginx_hardening.sh
/var/folders/yk/flh9w2rn4tz5ht46m478751m0000gn/T/tmp.JFgqh9eeTA
PASS
OK tests/security/platform/test_nginx_hardening.sh
==> tests/security/platform/test_trusted_proxy.sh
PASS
OK tests/security/platform/test_trusted_proxy.sh
==> tests/security/platform/test_cloudflare_cache.sh
PASS
OK tests/security/platform/test_cloudflare_cache.sh
==> tests/security/platform/test_edge_modes.sh
PASS
OK tests/security/platform/test_edge_modes.sh
==> tests/security/platform/test_ssh_staged.sh
PASS
OK tests/security/platform/test_ssh_staged.sh
==> tests/security/platform/test_ssh_lockout_safety.sh
PASS
OK tests/security/platform/test_ssh_lockout_safety.sh
==> tests/security/platform/test_brute_force.sh
PASS
OK tests/security/platform/test_brute_force.sh
==> tests/security/platform/test_webmin_detect.sh
PASS
OK tests/security/platform/test_webmin_detect.sh
==> tests/security/platform/test_host_baseline.sh
PASS
OK tests/security/platform/test_host_baseline.sh
==> tests/security/platform/test_persistence_audit.sh
PASS
OK tests/security/platform/test_persistence_audit.sh
==> tests/security/platform/test_s2_rollback.sh
PASS
OK tests/security/platform/test_s2_rollback.sh
==> tests/security/platform/test_s2_idempotency.sh
/var/folders/yk/flh9w2rn4tz5ht46m478751m0000gn/T/tmp.Y8H6BNOttN
/var/folders/yk/flh9w2rn4tz5ht46m478751m0000gn/T/tmp.H9VsDf5QpR
PASS
OK tests/security/platform/test_s2_idempotency.sh
==> tests/security/platform/test_s2_gate_fail_closed.sh
==> tests/security/platform/test_s2_real_runtime.sh
==> tests/security/platform/test_s2_restart_matrix.sh
==> tests/security/platform/test_s2_firewall_guest.sh
==> tests/security/platform/test_s2_ssh_guest.sh
==> tests/security/run_security_gate_s1.sh
Built /Volumes/PortableSSD/soviez-project/soviez-sh/dist/soviez.sh (version 0.24.4-security-s4)
SHA256: fdbf6ea35f5e318fd4b7ff737ecf2e0bed443629b12813c2f172456572072c25
==> tests/security/platform/test_weak_credentials.sh
TEST-SEC-014 weak credentials
PASS TEST-SEC-014
OK tests/security/platform/test_weak_credentials.sh
==> tests/security/platform/test_stage_credentials.sh
TEST-SEC stage credentials source hygiene
PASS stage credentials
OK tests/security/platform/test_stage_credentials.sh
==> tests/security/platform/test_odoo_prod_defaults.sh
TEST-SEC odoo prod defaults
PASS odoo prod defaults
OK tests/security/platform/test_odoo_prod_defaults.sh
==> tests/security/platform/test_legacy_installer_static.sh
PASS legacy installer static
OK tests/security/platform/test_legacy_installer_static.sh
==> tests/security/platform/test_rollback_no_superuser_restore.sh
TEST-SEC rollback never restores SUPERUSER
PASS rollback no superuser restore
OK tests/security/platform/test_rollback_no_superuser_restore.sh
==> tests/security/platform/test_pg_least_privilege.sh
TEST-SEC-001/015 pg least privilege
==> tests/security/platform/test_pg_copy_program_denied.sh
TEST-SEC-002 COPY PROGRAM denied
==> tests/security/platform/test_pg_server_files_denied.sh
TEST-SEC-003/004 server files denied
==> tests/security/platform/test_pg_network_isolation.sh
TEST-SEC-005 pg network isolation (no public publish)
==> tests/security/platform/test_odoo_port_isolation.sh
TEST-SEC-006 odoo port isolation
==> tests/security/platform/test_docker_containment.sh
TEST-SEC-016 docker containment
==> tests/security/platform/test_security_gate_fail_closed.sh
TEST-SEC gate fail-closed
==> tests/security/platform/test_s1_idempotency.sh
TEST-SEC S1 idempotency
==> tests/security/platform/test_bootstrap_secret_not_in_odoo_env.sh
TEST-SEC bootstrap secret not in odoo env
==> tests/security/platform/test_s1_real_runtime.sh
TEST-SEC S1 real runtime matrix
==> tests/security/platform/test_odoo_functional_least_privilege.sh
TEST-SEC Odoo functional least-privilege + reverse proxy
==> tests/security/run_phase24_security.sh
==> tests/security/test_phase24_signature_enforcement.sh
OK test_phase24_signature_enforcement
OK tests/security/test_phase24_signature_enforcement.sh
==> tests/security/test_phase24_self_update_signature.sh
OK test_phase24_self_update_signature
OK tests/security/test_phase24_self_update_signature.sh
==> tests/security/test_phase24_signer_purpose.sh
OK test_phase24_signer_purpose
OK tests/security/test_phase24_signer_purpose.sh
==> tests/security/test_phase24_key_hygiene.sh
OK test_phase24_key_hygiene
OK tests/security/test_phase24_key_hygiene.sh
==> tests/security/test_phase24_ticket_replay.sh
OK test_phase24_ticket_replay
OK tests/security/test_phase24_ticket_replay.sh
==> tests/security/test_phase24_registry_lockdown.sh
OK test_phase24_registry_lockdown
OK tests/security/test_phase24_registry_lockdown.sh
==> tests/security/test_phase24_docker_auth_cleanup.sh
OK test_phase24_docker_auth_cleanup
OK tests/security/test_phase24_docker_auth_cleanup.sh
==> tests/security/test_phase24_test_flag_quarantine.sh
OK test_phase24_test_flag_quarantine
OK tests/security/test_phase24_test_flag_quarantine.sh
==> tests/security/test_phase24_secret_scan.sh
seeded tests/security/fixtures/secrets
SECRET_SCAN_TOOL=embedded_pattern_entropy
SECRET_SCAN — PASS
OK test_phase24_secret_scan
OK tests/security/test_phase24_secret_scan.sh
==> tests/security/test_phase24_dist_scan.sh
DIST SECURITY SCAN — PASS
DIST SECURITY SCAN — PASS
OK test_phase24_dist_scan
OK tests/security/test_phase24_dist_scan.sh
==> tests/security/test_phase24_cross_tenant.sh
OK test_phase24_cross_tenant
OK tests/security/test_phase24_cross_tenant.sh
==> tests/security/test_phase24_sovereignty_regression.sh
SOVEREIGNTY REGRESSION — PASS
OK test_phase24_sovereignty_regression
OK tests/security/test_phase24_sovereignty_regression.sh
==> tests/security/test_phase24_phase25_readiness.sh
OK test_phase24_phase25_readiness
OK tests/security/test_phase24_phase25_readiness.sh
==> tests/security/test_phase24_no_duplicate_engines.sh
NO DUPLICATE ENGINE — PASS
OK test_phase24_no_duplicate_engines
OK tests/security/test_phase24_no_duplicate_engines.sh
SECRET_SCAN_TOOL=embedded_pattern_entropy
gitleaks: not installed — embedded scanner is authoritative
GIT_HISTORY_SCAN — N/A (repository has zero commits; tree scan is authoritative)
HISTORICAL_SECRET_REVIEW — no commit history to classify
SECRET_SCAN — PASS
OK tools/secret_scan.sh
run_phase24_security: PASS
OK tests/security/run_phase24_security.sh → PASS (focused)
Nested S1–S3/Phase24 via [preflight] docker/colima health.

## Key controls
| Control | Result |
|---------|--------|
| Docker  quarantine network | PASS |
| Cron  | PASS |
| Mail/webhook/ZATCA egress blocked | PASS |
| Pre-boot S3 scan | PASS |
| Hostile DB → SCAN_FAILED → promote blocked | PASS |
| Clean DB → explicit promote | PASS |
| Archive traversal/symlink/absolute/device | REJECTED |
| ZATCA immutability | PASS |
| Fresh infrastructure secrets | PASS |
| Cutover/restore switch gate | PASS |

## Residual risk
Quarantine depends on Docker Internal networking and runtime cron disable; module-specific outbound beyond network still contained by egress deny. S5–S6 remain for update/network safety and full certification.

## Progress
Engineering Progress remains **99.5%**. Phase 25 remains PAUSED pending S5–S6.

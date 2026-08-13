# TEST_SEC_001_024_MATRIX

Focused matrix runner: `test_s6_test_sec_matrix.sh` → **PASS** (`fail_count=0`, `ids=24`).

Mode note: with `SOVIEZ_S6_SKIP_NESTED_REGRESSIONS=1`, matrix may use light mode for guest-heavy IDs already owned by S1–S5; unique certs still execute. Nested full execute remains **PENDING** if still running.

| ID | Control | Owner script(s) | Result |
|----|---------|-----------------|--------|
| TEST-SEC-001 | PG least privilege | `tests/security/platform/test_pg_least_privilege.sh` | PASS |
| TEST-SEC-002 | COPY PROGRAM denied | `tests/security/platform/test_pg_copy_program_denied.sh` | PASS |
| TEST-SEC-003 | Server files denied | `tests/security/platform/test_pg_server_files_denied.sh` | PASS |
| TEST-SEC-004 | Server files denied (paired) | `tests/security/platform/test_pg_server_files_denied.sh` | PASS |
| TEST-SEC-005 | PG network isolation | `tests/security/platform/test_pg_network_isolation.sh` | PASS |
| TEST-SEC-006 | Odoo port isolation | `tests/security/platform/test_odoo_port_isolation.sh` | PASS |
| TEST-SEC-007 | Nginx hardening | `tests/security/platform/test_nginx_hardening.sh` | PASS |
| TEST-SEC-008 | S2 real runtime | `tests/security/platform/test_s2_real_runtime.sh` | PASS |
| TEST-SEC-009 | Odoo functional least privilege | `tests/security/platform/test_odoo_functional_least_privilege.sh` | PASS |
| TEST-SEC-010 | Docker restart matrix (S5) | `tests/security/update_safety/test_s5_docker_restart_matrix.sh` | PASS |
| TEST-SEC-011 | Network fault inject (S5) | `tests/security/update_safety/test_s5_network_fault_inject.sh` | PASS |
| TEST-SEC-012 | S2 restart matrix | `tests/security/platform/test_s2_restart_matrix.sh` | PASS |
| TEST-SEC-013 | S2 restart matrix (paired) | `tests/security/platform/test_s2_restart_matrix.sh` | PASS |
| TEST-SEC-014 | Weak credentials | `tests/security/platform/test_weak_credentials.sh` | PASS |
| TEST-SEC-015 | PG least privilege (paired) | `tests/security/platform/test_pg_least_privilege.sh` | PASS |
| TEST-SEC-016 | Docker containment | `tests/security/platform/test_docker_containment.sh` | PASS |
| TEST-SEC-017 | DB classifier fixtures | `tests/security/detection/test_db_classifier_fixtures.sh` | PASS |
| TEST-SEC-018 | DB scan real Odoo schema | `tests/security/detection/test_db_scan_real_odoo_schema.sh` | PASS |
| TEST-SEC-019 | Network egress / cron quarantine | `tests/security/quarantine/test_network_egress_cron.sh` | PASS |
| TEST-SEC-020 | Backup integrity + promote | `backup_safety + quarantine/test_state_promotion.sh` | PASS |
| TEST-SEC-021 | ZATCA immutability (synthetic) | `detection / synthetic hash proof` | PASS |
| TEST-SEC-022 | Evidence fail-closed retention | `tests/security/detection/test_evidence_failclosed_retention.sh` | PASS |
| TEST-SEC-023 | S1/S2 idempotency | `test_s1_idempotency + test_s2_idempotency` | PASS |
| TEST-SEC-024 | Firewall reboot guests | `S5 firewall guest + S2 firewall guest` | PASS |

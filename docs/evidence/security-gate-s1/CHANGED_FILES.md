# Changed files — Security Gate S1

## Created
- src/security/platform/*.sh (report, secrets_baseline, credential_policy, postgres_roles, postgres_network, odoo_exposure, docker_containment, odoo_defaults, rollback, remediate_existing, critical_gate, legacy_bridge)
- src/commands/security_platform.sh
- tests/helpers/s1_platform.sh
- tests/security/run_security_gate_s1.sh
- tests/security/platform/test_*.sh
- docs/security/*.md
- docs/evidence/security-gate-s1/*

## Modified
- VERSION → 0.24.1-security-s1
- build/assemble.sh
- src/security/codes.sh
- src/security/readiness.sh (CLI status still Phase 24; platform commands separate)
- src/cli/parse.sh, src/entrypoint.sh, src/commands/new.sh
- src/database/provision.sh, src/docker/provision.sh
- src/migration/staging/startup.sh, src/update/real_docker.sh, src/backup/restore_test.sh
- tests/run_all.sh
- tests/security/test_phase24_dist_scan.sh (+ phase20/21/22 version accept)
- Soviez ERP/soviez.sh + soviez-deploy/soviez.sh (byte-identical)
- dist/soviez.sh regenerated

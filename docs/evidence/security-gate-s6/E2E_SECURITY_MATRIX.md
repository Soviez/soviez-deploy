# E2E_SECURITY_MATRIX

Focused `test_s6_e2e_security_chain.sh` → **PASS**

Chained owners exercised (representative):
- Quarantine hostile/clean scan + promote + egress/cron
- Detection classifier / YARA-process / host persistence fixtures
- S5 baseline/matrix (PDF inject FAIL; network inject FAIL→FAILED_PRECHECK)
- Backup integrity posture + off-host fixture (LOCAL_ONLY ≠ DR; MinIO/SFTP classified)
- Phase 23 offline bundle security

Adversarial matrix (`test_s6_adversarial_matrix.sh`) → **PASS** (COPY PROGRAM, server files, least privilege, docker/odoo isolation, archive safety, rollback no-superuser, webmin detect, APT corr suite).

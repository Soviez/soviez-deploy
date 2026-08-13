# TEST_RESULTS

## S5 focused suite
`SOVIEZ_S5_SKIP_NESTED_REGRESSIONS=1 bash tests/security/run_security_gate_s5.sh` → **PASS**

Includes:
- `test_s5_baseline_and_matrix.sh`
- `test_s5_docker_restart_matrix.sh` → PASS
- `test_s5_firewall_reboot_guest.sh` → Ubuntu 22.04 & 24.04 PASS
- `test_s5_package_policy.sh` → APT wait-only SAFE
- `test_s5_pdf_smoke.sh` → synthetic PASS; inject FAIL works; wkhtmltopdf N/A on stock ubuntu:24.04
- `test_s5_network_fault_inject.sh`
- `test_s5_backup_integrity_posture.sh` → PASS
- `test_s5_offhost_fixture.sh` → MinIO disposable + SFTP classify PASS

## Full material regression
`bash tests/run_all.sh` → **PASS**
- Count: **258 OK / 0 FAIL**
- Exact final exit code: **0**

Installer `0.24.5-security-s5`  
SHA256 `d42791352b5825e6484c4ff8304d6e2249faf44b2b9082ed5233b96fa809cf42`

Prior S1–S4 PASS preserved.

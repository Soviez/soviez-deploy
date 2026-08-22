# SECRET_SCAN
/Volumes/PortableSSD/soviez-project/soviez-deploy/tests/integration/test_stage_offline_full_e2e.sh:76:! grep -q "BEGIN PRIVATE KEY" "$PKG"
/Volumes/PortableSSD/soviez-project/soviez-deploy/tests/integration/test_stage_disconnect_resume_e2e.sh:129:  ! grep -Eiq 'BEGIN PRIVATE KEY|password=|activation_key' "$(soviez_systemd_unit_path "$op")" || false
/Volumes/PortableSSD/soviez-project/soviez-deploy/tests/integration/test_stage_disconnect_resume_e2e.sh:130:  ! grep -Eiq 'BEGIN PRIVATE KEY' "$(soviez_stage_op_state_file "$op")" || false
/Volumes/PortableSSD/soviez-project/soviez-deploy/tests/integration/test_backup_sftp_real.sh:256:if grep -R "BEGIN OPENSSH PRIVATE KEY" "$SOVIEZ_BACKUP_OPS_DIR" "$SOVIEZ_BACKUP_INVENTORY_DIR" 2>/dev/null; then
/Volumes/PortableSSD/soviez-project/soviez-deploy/tests/integration/test_phase23_real_ed25519.sh:51:grep -q 'BEGIN PRIVATE KEY' "$priv" || { echo "FAIL: private key is not real PEM"; exit 1; }
/Volumes/PortableSSD/soviez-project/soviez-deploy/src/platform/install.sh:71:    if grep -Rql 'BEGIN PRIVATE KEY' "${tmpdir}/trust" 2>/dev/null; then
/Volumes/PortableSSD/soviez-project/soviez-deploy/src/commands/stage_offline.sh:99:for bad in ("BEGIN PRIVATE KEY", "service_role", "activation_key", "DATABASE_PASSWORD"):
/Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/test_phase17_secret_handling.sh:50:! rg -n 'BEGIN PRIVATE KEY|password=|SECRET=' "$ROOT/dist/soviez.sh" | head -5 | grep -q .
/Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/test_phase24_secret_scan.sh:27:    "-----BEGIN RSA PRIVATE KEY-----\n"
/Volumes/PortableSSD/soviez-project/soviez-deploy/tests/security/fixtures/secrets/synthetic.pem:1:-----BEGIN RSA PRIVATE KEY-----
/Volumes/PortableSSD/soviez-project/soviez-deploy/tests/unit/test_ssl_lifecycle.sh:153:assert_not_contains "$out" "BEGIN PRIVATE KEY"
status=FAIL
/Volumes/PortableSSD/soviez-project/soviez-deploy/tools/platform_release_sign.sh:7:PRIV="${SOVIEZ_PLATFORM_STAGING_PRIVKEY:-/Volumes/PortableSSD/soviez-project/.secrets/staging-platform-keys/soviez-platform-staging-2026-08.key}"

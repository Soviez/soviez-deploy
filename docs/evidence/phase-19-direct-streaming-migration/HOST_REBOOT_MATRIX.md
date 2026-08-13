# HOST_REBOOT_MATRIX.md

Suite: `tests/integration/test_phase19_host_reboot_matrix.sh`

- Actual Colima VM stop/start (not state-file-only)
- Skip flag fails certification (`SOVIEZ_PHASE19_REQUIRE_HOST_REBOOT`)
- Authoritative run: **PASS** (Colima stop/start logged in `/tmp/p19-auth-run-all-CLEAN.log`)
- Post-reboot: operation/manifest retention, freeze reconcile, token unchanged, destination non-Production

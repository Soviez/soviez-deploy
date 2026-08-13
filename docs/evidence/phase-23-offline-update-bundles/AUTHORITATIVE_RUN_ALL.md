# AUTHORITATIVE_RUN_ALL

Started: 2026-08-09T20:16:44Z
DOCKER_HOST=unix:///Users/raafatagha/.colima/default/docker.sock
SOVIEZ_PHASE23_CERTIFICATION=1
Installer candidate: 0.23.0-phase23

OK /Volumes/PortableSSD/soviez-project/soviez-sh/tests/unit/test_phase23_docker_preflight.sh
OK /Volumes/PortableSSD/soviez-project/soviez-sh/tests/unit/test_phase23_postgres_preflight.sh
OK /Volumes/PortableSSD/soviez-project/soviez-sh/tests/unit/test_phase23_exact_fixture_reset.sh
OK /Volumes/PortableSSD/soviez-project/soviez-sh/tests/unit/test_phase23_failure_classification.sh
OK /Volumes/PortableSSD/soviez-project/soviez-sh/tests/unit/test_phase23_evidence_finalizer.sh
OK /Volumes/PortableSSD/soviez-project/soviez-sh/tests/unit/test_phase23_offline_bundle_unit.sh
OK /Volumes/PortableSSD/soviez-project/soviez-sh/tests/integration/test_phase23_real_registry_oci.sh
OK /Volumes/PortableSSD/soviez-project/soviez-sh/tests/integration/test_phase23_real_ed25519.sh
OK /Volumes/PortableSSD/soviez-project/soviez-sh/tests/integration/test_phase23_real_airgapped_apply.sh
OK /Volumes/PortableSSD/soviez-project/soviez-sh/tests/integration/test_phase23_offline_bundle_integration.sh
OK /Volumes/PortableSSD/soviez-project/soviez-sh/tests/integration/test_phase23_saas_schema_upgrade.sh
OK /Volumes/PortableSSD/soviez-project/soviez-sh/tests/integration/test_phase23_saas_typecheck_lint_build.sh
OK /Volumes/PortableSSD/soviez-project/soviez-sh/tests/security/test_phase23_offline_bundle_security.sh
## tests/run_all.sh
exit_code: 0
ok_count: 113
fail_count: 0
focused_ok: 13
focused_fail: 0
    time="2026-08-09T23:48:08+03:00" level=info msg="[hostagent] Stopping forwarding `[::1]:53` (guest) to `/tmp/lima-psl-127.0.0.1-53-2523178738/sock` (host)"
    time="2026-08-09T23:48:08+03:00" level=warning msg="[hostagent] failed to set up forwarding tcp port 53 (negligible if already forwarded)" error="listen tcp 0.0.0.0:53: bind: address already in use"
    time="2026-08-09T23:48:08+03:00" level=info msg="[hostagent] Not forwarding TCP [::]:22"
    time="2026-08-09T23:48:08+03:00" level=info msg="[hostagent] Not forwarding TCP [fe80::5055:55ff:fee3:ad41]:53"
    time="2026-08-09T23:48:11+03:00" level=info msg="[hostagent] The final requirement 1 of 1 is satisfied"
    time="2026-08-09T23:48:11+03:00" level=info msg="READY. Run `limactl shell colima` to open the shell."
    installing: 386 OK
    installing: amd64 OK
    {
      "supported": [
        "linux/arm64",
        "linux/amd64",
        "linux/386"
      ],
      "emulators": [
        "python3.12",
        "qemu-i386",
        "qemu-x86_64"
      ]
    }
    time="2026-08-09T23:48:12+03:00" level=info msg="provisioning ..." context=docker
    colima
    Successfully created context "colima"
    colima
    Current context is now "colima"
    Warning: DOCKER_HOST environment variable overrides the active context. To use "colima", either set the global --context flag, or unset DOCKER_HOST environment variable.
    time="2026-08-09T23:48:13+03:00" level=info msg="starting ..." context=docker
    time="2026-08-09T23:48:14+03:00" level=info msg=done
    test_phase22_source_autostart_prevention: PASS
    OK tests/integration/test_phase22_source_autostart_prevention.sh
    [phase23-preflight] ERP fixture labels present (distinct digests)
    ==> tests/integration/test_phase23_real_reboot_powerloss.sh
    [phase23-preflight] Docker OK
    == issue + import offline bundle ==
    == apply #1 (pre-reboot, must succeed exactly once) ==
    OP_ID_1=ou-20260809204820-32384
    == write pre-reboot checkpoint from soviez_offline_replay state ==
    [checkpoint] {"apply_state": "applied_success", "authorization_id": "auth-bun-reboot-32384", "bundle_id": "bun-reboot-32384", "bundle_json": "/Volumes/PortableSSD/soviez-project/.phase23-cert-tmp/20260809T201641Z-78190/p23-reboot.5hnLXv/bundles/staging/imp-20260809204818-32384/tree/bundle.json", "device_fingerprint": "fp-reboot", "environment_id": "env-reboot", "first_imported_at": "2026-08-09T20:48:18Z", "last_inspected_at": "2026-08-09T20:48:19Z", "license_id": "lic-reboot", "manifest_digest": "sha256:48e4f513e5378588934dd859385d6fc45f1d4e629ce61ec92e4fb8caed426645", "operation_id": "ou-20260809204820-32384", "reconciliation_state": "pending", "result_receipt_id": "result_receipt", "staging_dir": "/Volumes/PortableSSD/soviez-project/.phase23-cert-tmp/20260809T201641Z-78190/p23-reboot.5hnLXv/bundles/staging/imp-20260809204818-32384", "successful_apply_count": 1}
    [assert] pre-reboot checkpoint recorded: op=ou-20260809204820-32384 state=applied_success count=1
    == REAL interruption: colima stop && colima start (once) ==
    == waiting for Docker recovery post-restart (bounded) ==
    [assert] Docker recovered post-restart after 1 probe(s)
    == host-side state survived the VM interruption unchanged ==
    [assert] same operation id (ou-20260809204820-32384) before and after the interruption; checkpoint and live replay DB agree
    == apply #2 (post-reboot, resume by known bundle id) MUST be denied as a duplicate ==
    apply #2 exit=25
    [error] offline:OFFLINE_BUNDLE_ALREADY_APPLIED: Bundle already applied successfully
    [assert] post-reboot re-apply correctly denied: OFFLINE_BUNDLE_ALREADY_APPLIED
    == final replay state unchanged by the denied duplicate attempt ==
    [assert] operation identity (ou-20260809204820-32384) and apply count (1) remain exactly as they were — no duplicate apply, real reboot survived
    OK test_phase23_real_reboot_powerloss
    OK tests/integration/test_phase23_real_reboot_powerloss.sh
    [phase23-preflight] ERP fixture labels present (distinct digests)
    ==> tests/integration/test_update_final_certification.sh
    {"ok":false,"code":"UPDATE_RECOVERY_REQUIRED","interrupted_at":"upgrading_candidate","operation_id":"upd-interrupt-test"}
    PASS test_update_final_certification
    soviez-upd-cand-upd-20260809234852-8be4a008
    OK tests/integration/test_update_final_certification.sh
    [phase23-preflight] ERP fixture labels present (distinct digests)
    run_all: PASS

## evidence_finalizer
exit_code: 0

## Aggregate
phase23_authoritative_certification: PASS
aggregate_exit_code: 0
Finished: 2026-08-09T20:50:13Z

# AUTHORITATIVE_RUN_ALL

Started: 2026-08-09T19:39:52Z
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
0
focused_ok: 13
focused_fail: 0
    time="2026-08-09T23:12:06+03:00" level=info msg="[hostagent] Forwarding TCP from 127.0.0.1:6379 to 127.0.0.1:6379"
    time="2026-08-09T23:12:06+03:00" level=info msg="[hostagent] Forwarding TCP from 127.0.0.1:8313 to 127.0.0.1:8313"
    time="2026-08-09T23:12:06+03:00" level=info msg="[hostagent] Forwarding TCP from 127.0.0.1:5432 to 127.0.0.1:5432"
    time="2026-08-09T23:12:06+03:00" level=warning msg="[hostagent] failed to set up forwarding tcp port 5432 (negligible if already forwarded)" error="failed to run [ssh -F /dev/null -o IdentityFile=\"/Volumes/PortableSSD/Apps/Colima/Home/.colima/_lima/_config/user\" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o NoHostAuthenticationForLocalhost=yes -o PreferredAuthentications=publickey -o Compression=no -o BatchMode=yes -o IdentitiesOnly=yes -o GSSAPIAuthentication=no -o Ciphers=\"^aes128-gcm@openssh.com,aes256-gcm@openssh.com\" -o User=raafatagha -o ControlMaster=auto -o ControlPath=\"/Volumes/PortableSSD/Apps/Colima/Home/.colima/_lima/colima/ssh.sock\" -o ControlPersist=yes -T -O forward -L 127.0.0.1:5432:127.0.0.1:5432 -N -f -p 56624 127.0.0.1 --]: ``: exit status 255"
    time="2026-08-09T23:12:07+03:00" level=info msg="[hostagent] The final requirement 1 of 1 is satisfied"
    time="2026-08-09T23:12:07+03:00" level=info msg="READY. Run `limactl shell colima` to open the shell."
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
    time="2026-08-09T23:12:08+03:00" level=info msg="provisioning ..." context=docker
    colima
    Successfully created context "colima"
    colima
    Current context is now "colima"
    Warning: DOCKER_HOST environment variable overrides the active context. To use "colima", either set the global --context flag, or unset DOCKER_HOST environment variable.
    time="2026-08-09T23:12:19+03:00" level=info msg="starting ..." context=docker
    time="2026-08-09T23:12:20+03:00" level=info msg=done
    test_phase22_source_autostart_prevention: PASS
    OK tests/integration/test_phase22_source_autostart_prevention.sh
    [phase23-preflight] ERP fixture labels present (distinct digests)
    ==> tests/integration/test_phase23_real_reboot_powerloss.sh
    [phase23-preflight] Docker OK
    == issue + import offline bundle ==
    == apply #1 (pre-reboot, must succeed exactly once) ==
    OP_ID_1=ou-20260809201226-66076
    == write pre-reboot checkpoint from soviez_offline_replay state ==
    [checkpoint] {"apply_state": "applied_success", "authorization_id": "auth-bun-reboot-66076", "bundle_id": "bun-reboot-66076", "bundle_json": "/Volumes/PortableSSD/soviez-project/.phase23-cert-tmp/20260809T193949Z-11867/p23-reboot.BWBNF1/bundles/staging/imp-20260809201225-66076/tree/bundle.json", "device_fingerprint": "fp-reboot", "environment_id": "env-reboot", "first_imported_at": "2026-08-09T20:12:25Z", "last_inspected_at": "2026-08-09T20:12:26Z", "license_id": "lic-reboot", "manifest_digest": "sha256:7b5a2a20396dab58b6e1f44918751cb44b0ce2be914e30d2459f4a241f9d0d3a", "operation_id": "ou-20260809201226-66076", "reconciliation_state": "pending", "result_receipt_id": "result_receipt", "staging_dir": "/Volumes/PortableSSD/soviez-project/.phase23-cert-tmp/20260809T193949Z-11867/p23-reboot.BWBNF1/bundles/staging/imp-20260809201225-66076", "successful_apply_count": 1}
    [assert] pre-reboot checkpoint recorded: op=ou-20260809201226-66076 state=applied_success count=1
    == REAL interruption: colima stop && colima start (once) ==
    == waiting for Docker recovery post-restart (bounded) ==
    [assert] Docker recovered post-restart after 1 probe(s)
    == host-side state survived the VM interruption unchanged ==
    [assert] same operation id (ou-20260809201226-66076) before and after the interruption; checkpoint and live replay DB agree
    == apply #2 (post-reboot, resume by known bundle id) MUST be denied as a duplicate ==
    apply #2 exit=25
    [error] offline:OFFLINE_BUNDLE_ALREADY_APPLIED: Bundle already applied successfully
    [assert] post-reboot re-apply correctly denied: OFFLINE_BUNDLE_ALREADY_APPLIED
    == final replay state unchanged by the denied duplicate attempt ==
    [assert] operation identity (ou-20260809201226-66076) and apply count (1) remain exactly as they were — no duplicate apply, real reboot survived
    OK test_phase23_real_reboot_powerloss
    OK tests/integration/test_phase23_real_reboot_powerloss.sh
    [phase23-preflight] ERP fixture labels present (distinct digests)
    ==> tests/integration/test_update_final_certification.sh
    {"ok":false,"code":"UPDATE_RECOVERY_REQUIRED","interrupted_at":"upgrading_candidate","operation_id":"upd-interrupt-test"}
    PASS test_update_final_certification
    soviez-upd-cand-upd-20260809231249-69206a67
    OK tests/integration/test_update_final_certification.sh
    [phase23-preflight] ERP fixture labels present (distinct digests)
    run_all: PASS

## evidence_finalizer
exit_code: 2

## Aggregate
phase23_authoritative_certification: FAIL
aggregate_exit_code: 1
Finished: 2026-08-09T20:14:15Z

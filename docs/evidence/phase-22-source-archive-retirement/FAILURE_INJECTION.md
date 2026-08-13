# FAILURE_INJECTION

**Result:** PASS (executable)

| Case | Command / suite | Expected | Actual |
|------|-----------------|----------|--------|
| SaaS 089 / upgrade / invalid archived | phase22 disposable PG proofs | fail closed / pass valid | PASS |
| duplicate archived transition | disposable PG | idempotent | PASS |
| multi-tenant collision | disposable PG | denied | PASS |
| host reboot during/after closure/archive/finalize/suspend | test_phase22_real_host_reboot_matrix | persist + idempotent | PASS |
| source auto-start | test_phase22_source_autostart_prevention | ALREADY_SUSPENDED | PASS |
| S3/SFTP partial upload | test_phase22_s3/sftp_interruption | TRANSFER_INTERRUPTED then resume | PASS |
| lost ack | test_phase22_archive_lost_ack | interrupt then ack | PASS |
| license response loss / commit unknown | test_phase22_license_finalization_response_loss | resolve no dup | PASS |
| runtime-stop response loss | test_phase22_runtime_suspend_response_loss | no dup suspend | PASS |
| unauthorized purge/delete/revoke/terminate | static + cert gates | die | PASS |

Invariants after each: destination traffic_owner, token=1, slot=1, no purge/delete/revoke/terminate, source data retained.

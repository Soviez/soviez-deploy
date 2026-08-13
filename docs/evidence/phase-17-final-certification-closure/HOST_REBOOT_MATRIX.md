# HOST_REBOOT_MATRIX.md

**Result:** PASS  

Suite: `tests/integration/test_phase17_reboot_matrix.sh` (Colima stop/start)  
Also: destination guest `docker restart` in `test_migration_destination_host_real.sh`

After host reboot: canonical ops survive on disk; source/destination IDs survive; no duplicate bootstrap/pair; no silent trust accept; token unchanged; no data transfer; source active; destination non-Production; `recovery_required` for ambiguous mid-flight pairing; completed irreversible checkpoints not repeated.

Harness: reboot matrices deferred to end of `tests/run_all.sh` to avoid orphaning mid-suite Docker networks.

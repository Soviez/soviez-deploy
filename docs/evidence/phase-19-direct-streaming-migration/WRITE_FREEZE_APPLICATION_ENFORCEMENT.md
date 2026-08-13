# WRITE_FREEZE_APPLICATION_ENFORCEMENT.md

## Mechanism
Exact-Production scoped write freeze via:
1. Durable freeze state JSON (`WRITE_FREEZE.active`) bound to operation_id + migration_pair_id
2. Loopback HTTP write-guard (`final_sync/write_guard.sh`) denying POST/PUT/PATCH/DELETE with deterministic 503 while active; GET remains allowed
3. Independent watchdog with expiry + ownership checks; release reasons: normal completion, timeout, operator abort, process crash recovery, host reboot recovery, terminal transfer failure, manual exact recovery

## Proofs (`test_phase19_real_write_freeze.sh` + cert E2E)
- Pre-freeze write allowed
- During-freeze write denied
- Read-only remains available
- Final dump/delta run under freeze (E2E)
- Freeze released; post-freeze write allowed
- Timeout auto-release
- Process-crash / host-reboot / Abort release paths exercised
- Terminal `source_write_freeze=false`

Marker-only freeze without guard is forbidden in certification mode.

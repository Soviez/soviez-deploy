# Operation Engine Model — Phase 16 (Proposed)

## New operation types

| Op type | Purpose |
|---------|---------|
| `production_backup` | Create Full (or advanced DB-only) Production backup |
| `backup_verification` | Archive integrity verification |
| `backup_restore_test` | Disposable restore-test |
| `production_restore` | Candidate-first Production restore + switch |
| `backup_retention_cleanup` | Apply retention / unpin-safe deletes |
| `backup_export` | Export backup unit to path |
| `backup_import` | Import/validate external archive into inventory |

All integrate with Phase 14 unified registry, heartbeats, cancel/recover, redacted logs.

## Production backup states (minimum)

```text
created
→ validating_target
→ validating_destination
→ calculating_capacity
→ preparing_consistency
→ backing_up_database
→ backing_up_filestore
→ writing_manifest
→ encrypting
→ transferring
→ verifying
→ completed
```

## Production restore states (minimum)

```text
created
→ validating_target
→ validating_backup
→ checking_compatibility
→ running_preflight
→ preserving_current_production
→ creating_restore_candidate
→ restoring_database
→ restoring_filestore
→ restoring_metadata
→ starting_candidate
→ validating_candidate
→ waiting_for_switch
→ switching
→ validating_production
→ completed
```

## Shared failure / control states

`failed_retryable` · `retry_scheduled` · `recovery_required` · `rollback_running` · `failed_terminal` · `canceled`

## Cancellation boundaries

| Phase | Cancel |
|-------|--------|
| Before irreversible switch | Cleanup candidate / partial archive; Production safe |
| During remote transfer | Abort upload; discard incomplete remote object |
| After switch | Not silent success; enter recovery/rollback paths |

## CLI proposal (not implemented this task)

```bash
sudo soviez.sh --backup <production-id>
sudo soviez.sh --backup <production-id> --destination <destination-id>
sudo soviez.sh --backup-status <operation-id>
sudo soviez.sh --backup-list
sudo soviez.sh --backup-show <backup-id>
sudo soviez.sh --backup-verify <backup-id>
sudo soviez.sh --backup-export <backup-id> --output <path>
sudo soviez.sh --backup-import <path>
sudo soviez.sh --backup-delete <backup-id>
sudo soviez.sh --backup-pin <backup-id>
sudo soviez.sh --backup-unpin <backup-id>
sudo soviez.sh --backup-schedule ...
sudo soviez.sh --restore <production-id> --backup <backup-id>
sudo soviez.sh --restore-status <operation-id>
sudo soviez.sh --restore-cancel <operation-id>
sudo soviez.sh --restore-retry <operation-id>
sudo soviez.sh --restore-recover <operation-id>
sudo soviez.sh --restore-rollback <operation-id>
```

Requirements: exact target rules; confirmation / non-TTY flags; JSON output option; local-only ops; secret input not via argv; English operator messages.

## Adapter readiness

Phase 14 adapters already reserve conceptual restore/backup slots — Phase 16 fills real workers without rebuilding the engine.

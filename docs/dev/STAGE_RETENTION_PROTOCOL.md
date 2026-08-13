# Stage Retention Protocol (Phase 13)

**Version:** `0.13.0-phase13` · **Exit class:** `SOVIEZ_ERR_RETENTION=21`  
**Authority:** `src/stage/retention_*.sh`; this protocol describes implemented behavior.

## CLI

| Command | Contract |
|---|---|
| `--stage-retention-status [ID]` | Print local deadlines, countdown, status, and banner. Without ID, enumerate retained Stages. |
| `--stage-retention-extend ID --days N [--yes]` | Set total lifetime from immutable creation. `N` must be integer, monotonic, and ≤60. |
| `--stage-retention-run ID` | Run deletion only when due; typed ID / `SOVIEZ_RETENTION_RUN_CONFIRM=ID` is required. |
| `--stage-retention-retry ID` | Resume a blocked, due, or recovery-required deletion. |
| `--stage-retention-reattach OP` | Locate the durable retention operation and resume it. |

`SOVIEZ_RETENTION_FORCE_DUE=1` is test-only. It still requires destructive confirmation.

## Record and time semantics

`retention.json` is written per Stage. `created_at` and `maximum_retention_deadline` are immutable. Defaults are `created_at + 14 calendar days`; maximum is `created_at + 60 calendar days`. The deadline is 23:59:59 in `SOVIEZ_RETENTION_HOST_TZ`, persisted as UTC. `days_remaining` compares local calendar dates, so it is a daily—not 24-hour-duration—countdown.

## State and execution

Normal derived states are `extension_available`, `extension_limit_reached`, and `deletion_due`. Destructive execution progresses through `final_backup_running`, `safe_shield_validating`, and `deletion_running`; failures resolve to `needs_action` or `recovery_required`. A mkdir lock serializes work. `completed_deletion_steps` makes deletion idempotent across retry, disconnect, and reboot.

Final backup must succeed, exist outside the Stage directory, and match its SHA-256 sidecar before Safe Shield runs. After Safe Shield, each exact owned resource is removed and the inventory is atomically updated. A tombstone is written before Stage directory removal.

## Stable failure codes

Important machine-readable codes include `RETENTION_METADATA_CORRUPT`, `RETENTION_MAXIMUM_EXCEEDED`, `RETENTION_EXTENSION_REDUCES_DEADLINE`, `FINAL_RETENTION_BACKUP_FAILED`, `SAFE_SHIELD_VALIDATION_FAILED`, `STAGE_PRODUCTION_COLLISION`, `STAGE_RESOURCE_OWNERSHIP_AMBIGUOUS`, `RETENTION_PARTIAL_DELETION`, and `RETENTION_DELETED`. Errors emit JSON on stderr and fail closed.

No scheduler action performs a network call or entitlement check.

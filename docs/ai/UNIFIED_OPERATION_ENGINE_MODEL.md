# Unified Operation Engine Model

**Phase:** 14  
**Version:** `0.14.0-phase14`  
**Schema:** `schema_version: 1`

## Objective

Consolidate Phase 8 (`--new`), Phase 11 (Stage), Phase 12 (SSL), and Phase 13 (retention) operation implementations behind one shared local-first operation engine without rebuilding proven persistence, workers, reattach, or checkpointing.

## Non-goals

- Phase 15+ (Safe Update, Backup/Restore product, Migration product, Offline Bundles)
- Changing commercial entitlement, Stage License, Device Authorization, SSL policy product behavior, or retention calendar policy
- SaaS UI changes; phone-home; automatic support-bundle upload
- Blind stale-lock steal; global host lock for all operations

## Earlier-phase ownership

| Capability | Owner phase | Reuse |
|------------|-------------|-------|
| `--new` state/events/heartbeat/reattach | 8 | `src/operations/*`; adapter `new` |
| Stage create checkpoints/workers/reboot | 11 | `src/stage/*`; adapter `stage_create` |
| SSL renew/retry/scheduler/rollback | 12 | `src/ssl/*`; adapters `ssl_renewal`/`ssl_repair` |
| Retention delete/Safe Shield/tombstones | 13 | `src/stage/retention_*`; adapter `retention_delete` |
| Unified schema/registry/locks/CLI | **14** | `src/ops/*` |

## Canonical schema

Records live at `$SOVIEZ_OPS_ROOT/operations/<id>/canonical.json` (`schema_version=1`, `engine_version=0.14.0-phase14`). Legacy `state.json` remains authoritative for command engines; migration is idempotent with `.pre-phase14.bak`.

## Shared lifecycle

Top-level states: `created`, `queued`, `starting`, `running`, `waiting`, `retry_scheduled`, `cancel_requested`, `canceling`, `rollback_running`, `recovery_required`, `completed`, `canceled`, `failed_retryable`, `failed_terminal`.

Command detail is preserved in `current_checkpoint` (e.g. `device_authorization_pending`, `database_restore`, `waiting_for_dns`, `final_backup`).

## Registry

Host-local index under `$SOVIEZ_OPS_ROOT/registry/{index,locks,history}`. List/filter/status/reconcile require no SaaS.

## Locking / conflicts

Exact resource locks (`env:`, `db:`, `nginx:`, …) with owner identity; stale → `OPERATION_LOCK_STALE` (no blind steal). Conflict matrix denies retention vs backup/drop/restore on same Stage; same-domain SSL attaches; unrelated Stages may coexist.

## Cancellation / retry / recovery

Unified CLI delegates boundaries to adapters. Irreversible checkpoints deny cancel. Recovery is distinct from retry and fail-closes on ambiguous destructive checkpoints.

## Reboot / orphan reconciliation

`soviez_ops_reconcile_one` classifies healthy / attach_existing / resume_safe / retry_scheduled / cleanup_terminal_metadata / recovery_required. PID reuse and host-identity mismatch → recovery_required.

## Scheduler coordination

`soviez_ops_scheduler_coordinate` holds soft host scheduler lock, runs SSL monitor apply then retention scan; exact-resource locks remain in command engines.

## Logging / redaction / history

Shared events + per-op logs via `soviez_redact_text`. Terminal outcomes append to registry history. No automatic upload.

## Migration

`soviez_ops_migrate_*` maps legacy Phase 8/11/12/13 states → shared state + checkpoint; dry-run and idempotent re-entry supported.

## Continuous Synchronization

The synchronization engine (`src/ops/sync.sh`) continuously and atomically projects legacy state transitions, checkpoints, and heartbeats into the canonical JSON schema and global registry, enforcing strict write ordering (legacy → canonical → registry → event → terminal history/cleanup) and optimistic concurrency control revisions.

## Sovereignty

Local-only registry/status/recovery. No phone-home. Support-bundle consent is explicit operator action (contract only in Phase 14).

## Phase 15 adapters (post–Phase 14)

Implemented in Safe Update final certification:
- `production_update` — exact Production digest update
- `update_image_cleanup` — post-window exact image delete; scheduled cleanup **superseded** by `production_update` on same env

Still reserved / unauthorized: backup/restore product (Phase 16), migration, full offline bundles.

## Future-phase integration

Adapters for backup/restore, migration, offline bundles remain **unauthorized** until owner approval.

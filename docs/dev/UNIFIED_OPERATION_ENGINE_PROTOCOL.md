# Unified Operation Engine Protocol

**Phase:** 14  
**Version:** `0.14.0-phase14`  
**Schema Version:** `1`  

## 1. Overview

The Unified Operation Engine is a consolidated, host-local protocol for managing, auditing, and executing operations across all `soviez-sh` sub-components (Phase 8 license activation, Phase 11 Stage creation, Phase 12 domain/SSL lifecycle, Phase 13 Stage retention, and Phase 15 `production_update` / `update_image_cleanup`). 

It aggregates existing operation engines behind a standardized metadata contract, localized indexing, strict locking, and a shared state machine, while delegating the low-level, high-fidelity execution steps to the original proven command-specific worker implementations.

## 2. Shared Directory Layout

All state information, locks, and history are kept locally under `$SOVIEZ_OPS_ROOT/registry` with strictly restricted permissions (`0700` directories, `0600` files).

```text
$SOVIEZ_OPS_ROOT/
├── registry/
│   ├── index/        # Summary JSON files of active/completed operations
│   ├── locks/        # Exact resource lock subdirectories (e.g. host:scheduler, env:stage_1)
│   └── history/      # Immutable audit trail files (*.jsonl)
└── operations/       # Operation-specific workspaces and logs
```

## 3. Canonical Record Schema

Every operation is represented by a canonical, secret-free JSON document located at:
`$SOVIEZ_OPS_ROOT/operations/<operation_id>/canonical.json`

### Field Definitions
- `schema_version`: (Integer) Always `1` for Phase 14.
- `engine_version`: (String) Always `0.14.0-phase14`.
- `operation_id`: (String) Unique UUID or identifier.
- `operation_type`: (String) One of `new`, `stage_create`, `ssl_renewal`, `ssl_repair`, `retention_delete`, `production_update`, `update_image_cleanup`.
- `environment_id`: (String/Null) Target environment (e.g., Stage ID).
- `current_state`: (String) Shared lifecycle state.
- `current_checkpoint`: (String) Command-specific fine-grained step identifier.
- `host_identity`: (String) Hostname where the operation was created.
- `worker_pid`: (Integer/Null) Running shell PID executing the operation.
- `updated_at`: (String) UTC timestamp.
- `meta`: (Object) JSON bag for optional state attributes.

Secrets are explicitly forbidden from the canonical file and are validated by a JSON scanner block prior to writing.

## 4. Shared Lifecycle State Machine

Operations follow a strict transition matrix:

```text
               ┌───────────┐
               │  created  │
               └─────┬─────┘
                     ▼
               ┌───────────┐
               │  queued   │
               └─────┬─────┘
                     ▼
               ┌───────────┐         ┌───────────┐
               │ starting  │ ◄───────┤ retry_sch │
               └─────┬─────┘         └─────▲─────┘
                     ├──────────────┐      │
                     ▼              ▼      │
               ┌───────────┐   ┌───────────┴┐
               │  running  │   │ failed_ret │
               └─────┬─────┴──►└────────────┘
                     ├──────────────┐
                     ▼              ▼
               ┌───────────┐   ┌────────────┐
               │  waiting  │   │ failed_term│
               └─────┬─────┘   └────────────┘
                     ├──────────────────────┐
                     ▼                      ▼
               ┌───────────┐         ┌──────────────┐
               │ cancel_req│         │ recovery_req │
               └─────┬─────┘         └──────────────┘
                     ▼
               ┌───────────┐
               │ canceling │
               └─────┬─────┘
                     ▼
               ┌───────────┐         ┌───────────┐
               │ completed │         │ canceled  │
               └───────────┘         └───────────┘
```

### Valid Transition Table
Transitions are verified by `soviez_ops_sm_can_transition`. Attempting an illegal transition triggers an `OPERATION_TRANSITION_INVALID` error.

## 5. Heartbeat & Liveness

Workers append heartbeat updates to:
`$SOVIEZ_OPS_ROOT/operations/<operation_id>/heartbeat`

An operation is declared `OPERATION_HEARTBEAT_STALE` if the heartbeat has not been updated within 300 seconds and the worker PID is no longer alive.

## 6. Logs & Redaction

Command execution logs are stored at:
`$SOVIEZ_OPS_ROOT/operations/<operation_id>/operation.log`

All logs are written via `soviez_ops_log_append` which routes messages through `soviez_redact_text` to scrub any business datasets, database passwords, keys, tokens, or personal identifiers before write. No log streams are ever exported.

## 7. Continuous Canonical Synchronization

To bridge legacy execution engines with the unified registry, the sync engine (`src/ops/sync.sh`) continuously updates the canonical records (`canonical.json`), global indexes, and event logs. 

All sync transitions follow a strict write order:
1. Update legacy state file.
2. Upgrade legacy state to canonical JSON.
3. Update global registry index.
4. Append event log to history.
5. Finalize terminal state and release locks.

A monotonic revision model ensures that concurrent or out-of-order writes are rejected, and any stale or pending synchronization states block overlapping operations to prevent corruption.

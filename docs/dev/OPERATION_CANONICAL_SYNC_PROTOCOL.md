# Operation Canonical Sync Protocol (Phase 14)

**Version:** `0.14.0-phase14`  
**Authority:** `src/ops/sync.sh`; this protocol describes implemented behavior for continuous canonical synchronization.

## 1. Overview

The Canonical Synchronization Protocol ensures that any state transition, checkpoint update, or heartbeat modification within the `soviez-sh` operation engines is continuously, atomically, and idempotently synchronized from legacy command-specific formats to the Phase 14 unified canonical JSON format, global registry indexes, and immutable event logs.

It guarantees that legacy execution engines (Phase 8, 11, 12, and 13) can run unchanged, while their operational metadata is projected in real-time into a unified, queryable, and auditable local-first state.

---

## 2. Write Ordering

To prevent race conditions, partial writes, and inconsistent indexing, all synchronization updates must follow a strict, unidirectional write sequence:

1. **Legacy Write:** The command-specific engine updates its authoritative legacy state file (e.g., `state.json`, `retention.json`, or SSL status files).
2. **Canonical Upgrade:** The sync engine reads the updated legacy state and maps it to the Phase 14 canonical schema (`canonical.json`).
3. **Registry Indexing:** The global registry index (`$SOVIEZ_OPS_ROOT/registry/index/<op_id>.json`) is atomically updated to reflect the new state.
4. **Event Logging:** An immutable event record is appended to the global history log (`$SOVIEZ_OPS_ROOT/registry/history/history.jsonl`).
5. **Terminal History / Cleanup:** Upon reaching a terminal state (`completed`, `canceled`, `failed_terminal`), the operational locks are released, temporary workspace files are cleaned up, and the final state is committed to the registry history.

---

## 3. Revision Model

To ensure concurrency safety and prevent stale updates, the synchronization engine implements a optimistic concurrency control revision model:

- Every canonical record contains a monotonic `revision` integer (starting at `1`).
- Before any write to `canonical.json`, the engine reads the existing file and verifies that the incoming revision is exactly `current_revision + 1`.
- If a revision mismatch is detected, the transaction aborts with `OPERATION_SYNC_REVISION_CONFLICT` to prevent out-of-order updates.

---

## 4. Sync Status

The synchronization state of any operation is tracked via a dedicated `sync_status` field inside the canonical metadata:

- `SYNC_PENDING`: Legacies have been updated, but canonical or index write is incomplete.
- `SYNC_IN_PROGRESS`: The synchronization transaction is currently executing.
- `SYNC_COMPLETE`: Legacies, canonical, registry index, and event logs are fully aligned.
- `SYNC_FAILED`: The synchronization failed midway, marking the operation as requiring reconciliation.

---

## 5. Adapter API

The sync module `src/ops/sync.sh` exposes a standardized set of functions to orchestrate synchronization across all legacy engines:

- `soviez_ops_sync_create`: Initializes a new canonical sync record and registers the operation.
- `soviez_ops_sync_transition`: Moves the canonical state machine forward and updates the registry.
- `soviez_ops_sync_checkpoint`: Updates the fine-grained step checkpoint without changing top-level state.
- `soviez_ops_sync_heartbeat`: Appends a liveness heartbeat and updates the liveness index.
- `soviez_ops_sync_retry`: Re-registers and transitions a failed operation back to `starting` for retry.
- `soviez_ops_sync_cancel`: Triggers cancellation and coordinates with the legacy adapter.
- `soviez_ops_sync_rollback`: Executes rollback procedures for aborted operations.
- `soviez_ops_sync_recovery`: Recovers operations from failed or inconsistent synchronization states.
- `soviez_ops_sync_terminal`: Finalizes the operation, archives logs, and cleans up resources.
- `soviez_ops_sync_reconcile`: Reconciles active operations against process liveness and heartbeats.
- `soviez_ops_sync_from_legacy_file`: Reads a legacy state file and translates it into a canonical record.
- `soviez_ops_sync_apply`: Commits the synchronization transaction atomically to disk.

---

## 6. Failure Boundaries

Synchronization is designed to fail-close safely under all circumstances. The engine defines explicit failure boundaries:

- **Disk Full / Write Failure:** If writing the canonical or index file fails, the engine aborts and retains the legacy state as authoritative.
- **Process Crash:** If the worker process dies mid-sync, the next scheduler run or status check detects the mismatch and triggers reconciliation.
- **Controlled Failure Injection:** Developers can inject failures at specific synchronization stages using the `SOVIEZ_OPS_SYNC_FAIL_AT` environment variable (e.g., `SOVIEZ_OPS_SYNC_FAIL_AT=registry_write`).

---

## 7. Terminal Sync

When an operation reaches a terminal state (`completed`, `canceled`, `failed_terminal`), the terminal sync handler executes the following steps:

1. Writes the final `canonical.json` with the terminal state.
2. Appends the final outcome event to the global history log.
3. Deletes the active registry index file and moves it to the historical archive.
4. Atomically releases all acquired resource locks (`env:`, `db:`, `nginx:`).
5. Cleans up temporary files and workspaces.

---

## 8. Reconciliation

The liveness of all active operations is continuously monitored. If a mismatch is detected (e.g., the worker process is dead but the operation is still marked as `running`), the reconciliation engine classifies the state:

- **`resume_safe`**: The operation can be safely resumed from its last checkpoint.
- **`retry_scheduled`**: The operation is scheduled for a automatic retry.
- **`cleanup_terminal_metadata`**: Active indices and locks are cleaned up for an operation that completed but failed to release resources.
- **`recovery_required`**: A critical failure occurred during a destructive step, requiring manual operator intervention.

---

## 9. Conflict & Scheduler Protection

To prevent overlapping operations from corrupting system state, the scheduler and conflict manager enforce strict rules:

- **Sync-Pending Block:** The scheduler and CLI will refuse to start or queue any new operation if there is an existing operation in a `SYNC_PENDING` or unresolved state for the same environment.
- **Stale Sync-Pending Refusal:** If an overlapping operation is requested while a stale operation remains in a sync-pending state, the request is rejected with `OPERATION_RESOURCE_CONFLICT` until explicit recovery is run.

---

## 10. Performance

Continuous synchronization is optimized for low-overhead execution on self-hosted, resource-constrained environments:

- **No SaaS Round-trips:** All operations are 100% local-first. No network calls are made during synchronization.
- **Atomic Directory Operations:** Lock acquisition and state writes use atomic filesystem operations (`mkdir` and `mv`) to minimize disk I/O and avoid locking latency.
- **Incremental Indexing:** The global registry index is split into individual files per operation ID, avoiding the need to rewrite a single massive index file on every update.

---

## 11. Test Matrix

The synchronization engine is validated against a comprehensive test suite in `tests/run_all.sh`:

| Test Case | Description | Expected Outcome |
|---|---|---|
| `test_sync_create_and_apply` | Verifies initial sync creation and atomic write. | PASS |
| `test_sync_transition_matrix` | Validates strict state transition enforcement. | PASS |
| `test_sync_revision_conflict` | Injects out-of-order writes and verifies abort. | PASS |
| `test_sync_failure_injection` | Uses `SOVIEZ_OPS_SYNC_FAIL_AT` to verify fail-close. | PASS |
| `test_sync_reconciliation` | Simulates worker crash and verifies recovery classification. | PASS |
| `test_sync_conflict_refusal` | Verifies rejection of overlapping operations during sync-pending. | PASS |
| `test_sync_terminal_cleanup` | Verifies lock release and history archiving on completion. | PASS |

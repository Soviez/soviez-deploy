# Failure Boundary Matrix

This document defines the failure boundaries and error-handling behaviors of the continuous canonical synchronization engine.

## 1. Failure Scenarios and Behaviors

The synchronization engine is designed to fail-close safely, protecting system integrity under all filesystem and process failures:

| Failure Scenario | Detection Mechanism | Immediate Behavior | Recovery / Outcome |
|---|---|---|---|
| **Disk Full / Write Failure** | Filesystem write error code | Aborts sync transaction; retains legacy state. | Operation marked `SYNC_FAILED`; blocks overlapping ops. |
| **Worker Process Crash** | PID liveness check (`kill -0`) | Scheduler detects dead process with active state. | Reconciled to `resume_safe` or `recovery_required`. |
| **Out-of-Order Write** | OCC revision mismatch | Aborts write; raises `OPERATION_SYNC_REVISION_CONFLICT`. | Transitions to `SYNC_FAILED` for reconciliation. |
| **Stale Lock Directory** | Lock owner PID dead & heartbeat > 300s | Raises `OPERATION_LOCK_STALE` on next run. | Refuses blind steal; requires explicit recovery. |
| **Corrupt Canonical JSON** | JSON parsing validation | Fails validation; aborts read/write. | Marks operation as requiring manual recovery. |

## 2. Failure Injection via `SOVIEZ_OPS_SYNC_FAIL_AT`

To support rigorous testing, the sync engine supports controlled failure injection. By setting the `SOVIEZ_OPS_SYNC_FAIL_AT` environment variable, developers can simulate failures at specific execution points:

- `SOVIEZ_OPS_SYNC_FAIL_AT=canonical_write`: Simulates a failure immediately before writing `canonical.json`.
- `SOVIEZ_OPS_SYNC_FAIL_AT=registry_write`: Simulates a failure immediately before writing the global registry index.
- `SOVIEZ_OPS_SYNC_FAIL_AT=event_append`: Simulates a failure immediately before appending to the history event log.
- `SOVIEZ_OPS_SYNC_FAIL_AT=lock_release`: Simulates a failure during the lock release phase of a terminal transition.

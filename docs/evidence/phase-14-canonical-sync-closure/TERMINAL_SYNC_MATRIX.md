# Terminal Sync Matrix

This document defines the exact execution steps performed by the terminal synchronization handler when an operation reaches a final state.

## 1. Terminal States

The engine defines three terminal states:
- `completed`: The operation finished successfully.
- `canceled`: The operation was safely aborted by the operator.
- `failed_terminal`: The operation failed with a non-retryable error.

## 2. Terminal Sync Execution Matrix

Upon reaching any of these terminal states, the terminal sync handler (`soviez_ops_sync_terminal`) executes a strict cleanup and archiving sequence:

| Step | Action | Outcome |
|---|---|---|
| **1. Write Final Canonical** | Writes `canonical.json` with the terminal state and `revision = final`. | Canonical record is frozen. |
| **2. Log Final Event** | Appends the final outcome event to the global history log (`history.jsonl`). | Immutable audit trail is completed. |
| **3. Archive Index** | Deletes `$SOVIEZ_OPS_ROOT/registry/index/<op_id>.json`. | Operation is removed from active queries. |
| **4. Release Locks** | Recursively deletes all acquired resource locks (`env:`, `db:`, `nginx:`). | Resources are freed for future operations. |
| **5. Clean Workspace** | Cleans up temporary files, logs, and workspaces. | Disk space is reclaimed. |

## 3. Safety Guarantee

If any step in the terminal sync sequence fails (e.g., disk write failure during index archiving), the locks are **not** released. The operation remains in a `SYNC_FAILED` state, ensuring that resources are protected until reconciliation is run.

# Conflict Safety

This document describes how the Phase 14 conflict engine prevents overlapping operations and protects system state.

## 1. The Conflict Engine (`soviez_ops_conflict_decide`)

Before any operation starts or is queued, the engine queries all active operations in `$SOVIEZ_OPS_ROOT/registry/index/` and evaluates the relationship between the incoming operation and existing running operations.

## 2. Sync-Pending Block

A critical safety feature of the Phase 14 corrective closure is the **Sync-Pending Block**:

- If an existing operation is in a `SYNC_PENDING` or unresolved state for a target environment, the conflict engine strictly **refuses** to start or queue any new operation for that same environment.
- If an operator attempts to run an overlapping operation, the CLI aborts with exit code `22` and returns the `OPERATION_RESOURCE_CONFLICT` JSON payload.
- This prevents new operations from running against an environment whose actual state is ambiguous or partially synchronized.

## 3. Stale Sync-Pending Refusal

If an operation remains in a sync-pending state and its heartbeat is stale (older than 300 seconds), the conflict engine continues to refuse any new overlapping operations. The block can only be cleared by running the explicit recovery command:
`soviez --operation-recover <op_id>`
This ensures that the operator is aware of the synchronization failure and must consciously resolve it before proceeding.

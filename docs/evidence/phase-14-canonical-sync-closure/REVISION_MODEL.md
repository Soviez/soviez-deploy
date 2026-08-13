# Concurrency Revision Model

This document describes the optimistic concurrency control revision model implemented in the Phase 14 canonical synchronization engine.

## 1. Monotonic Revision Counter

Every canonical record (`canonical.json`) contains a `revision` field, which is a monotonic integer starting at `1` upon operation creation.

```json
{
  "operation_id": "op_98765",
  "current_state": "running",
  "revision": 4,
  "updated_at": "2026-07-31T12:05:00Z"
}
```

## 2. Optimistic Concurrency Control (OCC)

Before any write to the canonical file, the sync engine performs an atomic check-and-set transaction:

1. **Read-Phase:** The engine reads the existing `canonical.json` and extracts the `current_revision`.
2. **Validation-Phase:** The engine verifies that the incoming revision is exactly `current_revision + 1`.
3. **Write-Phase:** If validation succeeds, the engine writes the new canonical record with the bumped revision.

## 3. Conflict Handling

If a revision mismatch is detected (e.g., the incoming revision is less than or equal to the current revision, or skips a number):

- The write transaction is aborted immediately.
- The engine raises an `OPERATION_SYNC_REVISION_CONFLICT` error.
- The active operation transitions to a `SYNC_FAILED` state, marking it for reconciliation.
- This prevents out-of-order writes from background workers or concurrent CLI commands from corrupting the state.

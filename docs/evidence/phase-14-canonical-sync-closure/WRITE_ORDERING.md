# Write Ordering Protocol

This document details the strict, unidirectional write ordering enforced by the Phase 14 canonical synchronization engine.

## 1. The Write Sequence

To guarantee filesystem and state consistency, every operation update must execute the following steps in exact sequence:

```text
┌─────────────────────────────────────────────────────────┐
│ 1. Authoritative Legacy Write                           │
│    - Update legacy state.json, retention.json, etc.     │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Canonical JSON Upgrade                               │
│    - Read legacy, map to canonical.json, bump revision  │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│ 3. Global Registry Index Update                         │
│    - Write /registry/index/<op_id>.json atomically      │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│ 4. Immutable Event Log Append                           │
│    - Append transition event to history.jsonl           │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│ 5. Terminal History / Cleanup (If Terminal)             │
│    - Archive index, release locks, clean workspaces     │
└─────────────────────────────────────────────────────────┘
```

## 2. Rationale for the Sequence

- **Authoritative Legacy First:** Legacy engines remain the primary execution authority. If any subsequent synchronization step fails, the legacy state is preserved, and the system can fail-close safely.
- **Canonical Before Index:** Writing the canonical file before updating the registry index ensures that any index lookup always points to a valid, fully-formed canonical document.
- **Index Before Event Log:** Updating the index before appending to the event log ensures that the current state is queryable before the transition history is permanently recorded.
- **Locks Released Last:** Operational locks are only released after the final terminal state has been successfully committed to the canonical record, index, and event log, preventing concurrent operations from starting prematurely.

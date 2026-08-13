# Operation Engine

Owners: `src/operations/`, `src/ops/`.

## Responsibilities

- Persistent jobs with operation IDs
- State files + locks
- Reattach / retry / cancel / recover / reconcile
- Needs Action signaling
- Terminal disconnect resilience
- Canonical sync across registries

Protocols: `UNIFIED_OPERATION_ENGINE_PROTOCOL.md`, `OPERATION_CONFLICT_AND_LOCKING_PROTOCOL.md`.

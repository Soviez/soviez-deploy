# Changed Files Inventory

**Phase:** 14  
**Verdict:** PASS  
**Version:** `0.14.0-phase14`  

## 1. Newly Created Modules (`src/ops/*`)

All unified operations framework files were added strictly under the local sandbox `src/ops/` structure:

- `src/ops/paths.sh` — Global paths, index resolving, and workspace mapping.
- `src/ops/schema.sh` — Schema definitions, validation, and secret-erasure logic.
- `src/ops/registry.sh` — Local JSON registry indexing and query hooks.
- `src/ops/conflicts.sh` — Cross-command conflict detection and matrices.
- `src/ops/locks.sh` — Atomic resource directories and stale lock monitors.
- `src/ops/migration.sh` — Idempotent backward-compatible state remappers.
- `src/ops/transitions.sh` — State machine flow asserts and sequence modifiers.
- `src/ops/workers.sh` — Standard operations background helper hooks.
- `src/ops/reconciliation.sh` — Decision trees for orphaned process audits.
- `src/ops/systemd.sh` — Service unit builders, standard environment, and metadata hygiene.
- `src/ops/heartbeat.sh` — Liveness and heart-pulsing utilities.
- `src/ops/events.sh` — Operation events ledger appending and formatting.
- `src/ops/scheduler.sh` — Soft lock coordination for SSL and retention schedulers.
- `src/ops/cli_helpers.sh` — Status formatting, log tailers, and parameter validation.
- `src/ops/codes.sh` — Enumeration of uniform error return identifiers.
- `src/ops/cancellation.sh` — Reversibility boundaries and cancel handlers.
- `src/ops/retry.sh` — Uniform state rollback and retry trigger logic.
- `src/ops/recovery.sh` — High-level interactive repair handlers.
- `src/ops/history.sh` — Immutable terminal logs archiving under registry.

## 2. Integrated CLI Elements

- `src/commands/operations.sh` — Unified CLI commands execution mapping.
- `src/cli/parse.sh` — Added `--operations` and `--operation-*` argument routers.

# Root Cause Analysis

This document analyzes the technical challenges and root causes that necessitated the Phase 14 corrective canonical synchronization closure.

## 1. The Synchronization Gap

In earlier phases of `soviez-sh`, each command-specific engine implemented its own state management and persistence:
- **Phase 8 (`--new`):** Authoritative state stored in `$SOVIEZ_OPS_ROOT/operations/<id>/state.json`.
- **Phase 11 (Stage):** Authoritative state stored in Stage-specific workspaces.
- **Phase 12 (SSL):** Authoritative state stored in SSL-specific workspaces.
- **Phase 13 (Retention):** Authoritative state stored in `retention.json`.

When Phase 14 introduced the unified operation engine and global registry, it migrated historical operations. However, active background operations running on legacy engines could update their state files independently, bypassing the global registry index and event logs. This created a synchronization gap where the global registry could display stale or inconsistent operational states.

## 2. Concurrency and Out-of-Order Writes

Asynchronous background workers execute steps independently. Without a strict write ordering and revision model, rapid state transitions could result in race conditions where:
- A slower canonical write overwrites a newer state update.
- Global registry indexes reflect a stale state while the legacy file is already in a terminal state.
- Resource locks are released prematurely before the final state is committed to the registry history.

## 3. Corrective Resolution

The corrective closure addresses these root causes by:
1. Implementing continuous, real-time synchronization (`src/ops/sync.sh`) that intercepts and projects all legacy state transitions.
2. Enforcing a strict write ordering (legacy → canonical → registry → event → terminal history/cleanup).
3. Introducing a monotonic revision model to prevent out-of-order writes.
4. Hardening the conflict engine to reject overlapping operations when a sync-pending state exists.

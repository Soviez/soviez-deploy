# Sync Adapter Coverage

This document details how the continuous canonical synchronization engine is wired into all legacy execution engines across `soviez-sh`.

## 1. Wiring Map

The synchronization engine (`src/ops/sync.sh`) is integrated into the following core modules:

| Legacy Engine | Source File | Integration Hook | Purpose |
|---|---|---|---|
| **Phase 8 (`--new`)** | `src/operations/engine.sh` | State transitions & heartbeats | Synchronizes license activation, liveness, and manual/auto transitions. |
| **Phase 11 (Stage)** | `src/stage/engine.sh` | Creation checkpoints & worker liveness | Synchronizes Stage creation, database restores, and filestore copies. |
| **Phase 12 (SSL)** | `src/ssl/engine.sh` | `soviez_ssl_op_mark` | Synchronizes SSL renewal, DNS challenge retries, and Nginx reloads. |
| **Phase 13 (Retention)**| `src/stage/retention_inventory.sh` | `retention_patch` | Synchronizes retention sweeps, final backups, and Safe Shield validation. |

## 2. Integration Mechanics

- **Non-Invasive Hooks:** Integration is achieved by injecting lightweight synchronization hooks immediately following legacy state updates. This ensures that the core worker logic remains untouched and fully backward-compatible.
- **Idempotent Sidecars:** For engines where workspaces differ from the default layout, a canonical sidecar file is written next to the legacy state file, allowing both old command-specific readers and the new unified CLI to read the status.

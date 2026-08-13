# Synchronization Architecture

This document describes the high-level architecture of the Phase 14 continuous canonical synchronization engine.

## 1. Architectural Overview

The synchronization engine is designed as a local-first, low-overhead bridge between legacy execution engines and the unified global registry. It operates entirely on the host filesystem without any network dependencies.

```text
┌─────────────────────────────────────────────────────────┐
│                 Legacy Execution Engines                │
│   (Phase 8 --new, Phase 11 Stage, Phase 12 SSL, etc.)   │
└────────────────────────────┬────────────────────────────┘
                             │
                             │ 1. State Transition / Checkpoint
                             ▼
┌─────────────────────────────────────────────────────────┐
│               Sync Module (src/ops/sync.sh)             │
│   - Enforces Write Ordering & Optimistic Revisions      │
└────────────────────────────┬────────────────────────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │ 2. Write          │ 3. Update         │ 4. Append
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ Canonical JSON  │ │ Global Registry │ │ Immutable Event │
│(canonical.json) │ │  Index File     │ │   Log File      │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

## 2. Key Components

### 1. Synchronization Module (`src/ops/sync.sh`)
The core module containing all synchronization primitives. It exposes a standardized API (`soviez_ops_sync_*`) to create, transition, checkpoint, and finalize operations.

### 2. Canonical Record (`canonical.json`)
The single source of truth for the unified engine. It contains the standardized metadata, current state, fine-grained checkpoint, and a monotonic revision counter.

### 3. Global Registry Index
A host-local index located under `$SOVIEZ_OPS_ROOT/registry/index/` that allows the CLI to quickly query active and completed operations without scanning individual workspace directories.

### 4. Immutable Event Log
A JSONL-formatted history file (`$SOVIEZ_OPS_ROOT/registry/history/history.jsonl`) that records every state transition as an immutable audit trail.

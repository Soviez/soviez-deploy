# REBOOT_AND_RECOVERY_MODEL.md

**Date:** 2026-08-02  
**Depends on:** Phase 14 ops reboot recovery; Phase 16 host-disk matrices

## Goals

Survive host reboot / process kill mid-transfer without silent inconsistency or permanent source freeze.

## Requirements

| Concern | Behavior |
|---------|----------|
| Write freeze | Persist freeze intent; on boot **release or re-assert** per durable op state within hard timeout budget |
| Chunk registry | On durable disk; resume from last verified chunk |
| Ops heartbeat | `migration_transfer_*` recoverable like other Phase 14 ops |
| Split brain | Pair id + transfer id fencing; deny two finals |

## Recovery outcomes

- `FAILED_RECOVERABLE` → operator `resume`  
- Freeze timeout exceeded across reboot → force release + BLOCKED/WARNING  
- Corrupt registry → BLOCKED; do not invent digests  

## Tests (impl)

Host-disk reboot matrix: kill during pre-sync, during freeze, during apply; assert freeze not sticky beyond timeout; assert no token side effects.

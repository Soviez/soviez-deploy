# TRANSFER_STATE_MACHINE.md

**Date:** 2026-08-02

## High-level states

```text
PLANNED
  → PRECHECK
  → PRE_SYNC (loop)
  → FINAL_FREEZE
  → FINAL_TRANSFER
  → STAGING_APPLY
  → VALIDATE
  → READY_FOR_20   (PASS|WARNING)
  → BLOCKED        (terminal until operator action)
  → ABORTED
  → FAILED_RECOVERABLE  (resume registry intact)
```

## Freeze substates

`FREEZE_REQUESTED → FREEZE_ACTIVE → (TRANSFER|TIMEOUT) → FREEZE_RELEASED`  
Timeout ⇒ auto release; transfer marked WARNING/BLOCKED per consistency.

## Token / license invariants (all states)

`reserved=false`, `consumed=false`; eligibility check only.

## Ready-for-20

| Result | Meaning |
|--------|---------|
| PASS | Required payloads validated; staging ready; source ACTIVE |
| WARNING | Optional failures / soft policy gaps; owner may authorize Phase 20 |
| BLOCKED | Must not enter Phase 20 |

Ops types (proposed): `migration_transfer_plan|pre_sync|final|validate|abort|resume`.

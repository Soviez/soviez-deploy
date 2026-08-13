# Stage Discovery Model — Phase 17

Phase 17 **inventories** Stages; it **does not** transfer them.

## Per Stage record (minimum)

| Field | Default |
|-------|---------|
| Stage ID | |
| parent Production | Exact |
| image digest | |
| database size / filestore size | Aggregates |
| retention deadline | |
| status | |
| `selected_by_owner` | **`false`** |
| entitlement state | |
| domain/SSL state | Inspect |
| compatibility status | |

## Rules

- Do **not** silently include all Stages in migration scope.  
- Owner selection for later phases must be explicit (OD-13).  
- Expired Stages: display; selectability is OD-14 — do **not** extend retention because discovery ran.  
- Do not alter Stage retention clocks.  

## Transfer

Stage transfer = Phase **19** (+ entitlement rules). Phase 17 only proposes.

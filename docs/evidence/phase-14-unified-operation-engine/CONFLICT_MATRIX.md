# Conflict Matrix

**Phase:** 14  
**Verdict:** PASS  

## 1. Decision Logic

The conflict solver (`src/ops/conflicts.sh`) evaluates concurrent operational overlaps across resources or host engines.

## 2. Conflict Decision Resolution Matrix

| Target Command | Existing Running Command | Shared Environment? | Decided Action | System Behavior |
|---|---|---|---|---|
| `retention_delete`| `stage_backup` | Yes | **deny** | Returns `OPERATION_RESOURCE_CONFLICT`; aborts. |
| `retention_delete`| `stage_drop` | Yes | **deny** | Returns `OPERATION_RESOURCE_CONFLICT`; aborts. |
| `retention_delete`| `stage_restore` | Yes | **deny** | Returns `OPERATION_RESOURCE_CONFLICT`; aborts. |
| `stage_backup` | `retention_delete`| Yes | **deny** | Returns `OPERATION_RESOURCE_CONFLICT`; aborts. |
| `stage_create` | `stage_create` | Yes | **deny** | Returns `OPERATION_RESOURCE_CONFLICT`; aborts. |
| `ssl_renewal` | `ssl_renewal` | Yes (domain) | **attach_existing**| Attaches to running worker instead of double-calling. |
| `update` | `migrate` | Yes (Production) | **deny** | Returns `OPERATION_RESOURCE_CONFLICT`; aborts. |
| `update` | `restore` | Yes (Production) | **deny** | Returns `OPERATION_RESOURCE_CONFLICT`; aborts. |
| `stage_create` | `stage_create` | No | **allow** | Runs in parallel without network collisions. |

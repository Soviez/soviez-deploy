# Operation Conflict and Locking Protocol

**Phase:** 14  
**Version:** `0.14.0-phase14`  
**Schema Version:** `1`  

## 1. Overview

To prevent race conditions, data corruption, and overlapping configuration changes, the Soviez Unified Operation Engine implements a strict **resource-based locking mechanism** combined with a **cross-command conflict matrix**. No blind lock stealing or unmanaged concurrent actions are permitted in the local environment.

## 2. Lock Architecture

Locks are formatted as `kind:resource` strings and are standardized across engines:
- `env:<environment_id>`: Protects the lifecycle of a specific Stage environment.
- `db:<database_name>`: Protects database-specific dumps, restores, and retention cleanups.
- `nginx:<environment_id>`: Restricts exclusive routing and certificate updates for a target Stage domain.
- `host:scheduler`: A soft coordinator lock ensuring only one scheduler run (SSL renew or Retention sweep) runs at any given second.

## 3. Atomic Acquisition & Lock Files

Lock acquisition uses atomic directory creation (`mkdir`) inside the host-isolated locks repository:
`$SOVIEZ_OPS_ROOT/registry/locks/<lock_id_normalized>`

If creation succeeds, an `owner.json` file is written with strict `0600` permissions.

### Owner Metadata Structure
```json
{
  "operation_id": "op_98765",
  "lock_id": "env:stage-1",
  "pid": 12345,
  "generation": 1,
  "acquired_at": "2026-07-31T12:00:00Z"
}
```

### Stale Lock Protection
If `mkdir` fails, the engine inspects the existing lock directory. 
- If the owner process is dead (validated via `kill -0`) **and** the owner operation's heartbeat is stale (older than 300 seconds), the engine flags an `OPERATION_LOCK_STALE` error.
- Blind lock stealing is strictly forbidden. A stale lock must be reconciled explicitly using `soviez_ops_recover` to clean up resource integrity safely.

## 4. Cross-Command Conflict Matrix

Before any lock is acquired, the engine queries active operations in `$SOVIEZ_OPS_ROOT/registry/index/` and evaluates the relationship between the incoming operation and existing running/starting operations using `soviez_ops_conflict_decide`.

### Matrix Behavior

| Incoming Operation | Existing Operation | Environment Match | Outcome | Reason / Behavior |
|--------------------|--------------------|-------------------|---------|-------------------|
| `retention_delete` | `stage_backup`     | Same              | **DENY**| Prevent deleting data mid-backup. |
| `retention_delete` | `stage_drop`       | Same              | **DENY**| Concurrent teardown collision. |
| `retention_delete` | `stage_restore`    | Same              | **DENY**| Prevent restoring into a deleting environment. |
| `stage_create`     | `stage_create`     | Same              | **DENY**| Prevent duplicate creation. |
| `ssl_renewal`      | `ssl_renewal`      | Same (domain)     | **ATTACH**| Reattaches to existing SSL renew run instead of starting new. |
| `update`           | `migrate`          | Same (Production) | **DENY**| Prevent system update during active version migration. |
| `production_update`| `update_image_cleanup` (scheduled/waiting) | Same | **SUPERSEDE** | Cancel cleanup; update wins (`supersede_cleanup`). |
| `update_image_cleanup` | `production_update` | Same | **DENY** | No cleanup during active update. |
| `update_image_cleanup` | `update_image_cleanup` (deleting) | Same | **DENY** | No overlapping deletes. |
| `stage_create`     | `stage_create`     | Different         | **ALLOW**| Isolated Docker networks allow parallel setups. |

If a conflict is detected, the engine aborts with exit code `22` and prints the `OPERATION_RESOURCE_CONFLICT` JSON denial payload.

## 5. Sync-Pending Conflict Protection

To prevent concurrent operations from executing while an operation is in an inconsistent or partially-synchronized state:
- The conflict engine and scheduler will refuse to start or queue any new overlapping operations if there is an active operation in a `SYNC_PENDING` or unresolved state for the target environment.
- If a stale operation remains in a sync-pending state, any new overlapping operation is strictly rejected until an explicit recovery/reconciliation process (`soviez --operation-recover`) is executed by the operator.

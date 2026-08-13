# Unified Operations and Recovery Guide

This guide describes how to monitor, manage, cancel, and recover system operations in `soviez-sh`.

## 1. Local-First Sovereignty

All operational records, locks, indices, logs, and historical archives are stored **100% locally** on your self-hosted server. 
- **No data egress:** No operation data, logs, database dumps, filestores, or passwords are ever sent to Soviez SaaS.
- **Offline independence:** Status checks, list queries, lock releases, and recovery processes do not require an active internet connection.

---

## 2. Command Reference

The `soviez` CLI provides a unified suite of tools for operation control.

### Listing Operations
To list registered operations on this host, use:
```bash
# List all active operations
soviez --operations --active

# List all failed or recovery-required operations
soviez --operations --failed

# Filter by type (new, stage_create, ssl_renewal, retention_delete)
soviez --operations --type stage_create

# Filter by target environment ID
soviez --operations --environment stage-production-1
```

### Checking Status
To view detailed status, active locks, current step checkpoints, and process identifiers, run:
```bash
soviez --operation-status op_10293c
```

### Reattaching to Disconnected Operations
If your SSH connection drops or you need to resume an interrupted long-running task, reattach instantly:
```bash
soviez --operation-reattach op_10293c
```
This resumes the worker from its last completed checkpoint, avoiding double-execution of heavy database restorations or file transfers.

### Canceling Operations
To stop an active operation safely:
```bash
soviez --operation-cancel op_10293c
```
- **Irreversible Steps:** Steps like database drops, database restoration, or deletion steps cannot be canceled. The engine will refuse to abort.
- **Rollback Steps:** Steps involving Nginx configuration changes or route reloads require confirmation (`--yes`) because they will trigger an automatic system rollback to the last known stable state:
  ```bash
  soviez --operation-cancel op_10293c --yes
  ```

### Retrying Failed Operations
If an operation fails with a retryable state (`failed_retryable`), you can retry it:
```bash
soviez --operation-retry op_10293c
```
This increments the retry counter and transitions the state machine back to `starting`.

### Operation Log Tailing
Inspect redacted, safe diagnostic output directly from your terminal:
```bash
# Get the last 100 lines of logs
soviez --operation-logs op_10293c 100
```

---

## 3. Recovery and Stale Locks

### Stale Locks
When a host reboots or an active SSH session is killed abruptly, a lock may remain held. When you try to run another operation, you might see this error:
`OPERATION_LOCK_STALE: Stale lock requires reconciliation`

This indicates that a lock directory exists, but the recording process ID is no longer active on the server.

### Reconciliation
To resolve stale locks and clean up terminal metadata safely, run:
```bash
soviez --operation-recover op_10293c
```
The recovery manager will evaluate the state of the operation:
1. **resume_safe / retry_scheduled:** If the checkpoint is safe to resume, the command triggers a safe background restart.
2. **recovery_required:** If the worker died during a destructive step (e.g. midway through a database drop or file cleanup), recovery is marked as required. The operator must inspect the target resources manually and then confirm recovery:
   ```bash
   soviez --operation-recover op_10293c --yes
   ```
3. **cleanup_terminal_metadata:** Cleans up unused indices, commits the record to the immutable history log, and safely releases the resources.

### Continuous Synchronization and Failure Boundaries

All background operation states are continuously synchronized in real-time. If a synchronization failure occurs (e.g., due to a disk full condition or unexpected crash), the engine fail-closes safely. The target environment is protected by rejecting any overlapping operations until the operator runs `soviez --operation-recover` to resolve the sync-pending state.

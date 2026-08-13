# Orphan Reconciliation

**Phase:** 14  
**Verdict:** PASS  

## 1. Reconciliation Decision Tree

An operation is declared an orphan if its worker process is dead and its heartbeat is stale. The orchestrator maps the orphan to recovery paths using `src/ops/reconciliation.sh`:

1. **Identity Guard Check:** Checks `host_identity` in the canonical JSON against the current hostname FQDN. Mismatches instantly transition the operation to `recovery_required` to prevent unsafe cross-host modifications.
2. **Process Integrity Check:** Checks the registered `worker_pid` using `ps -p`. If a process is alive but does not contain strings like `soviez`, `bash`, or `systemd`, it flags PID reuse and transitions to `recovery_required`.
3. **Checkpoint Assessment:** 
   - If the checkpoint matches destructive phrases (`delete*`, `drop*`, `restore*`, `promote*`, `tenant_identity*`), the state is declared `recovery_required`.
   - Otherwise, it transitions to `resume_safe` to schedule re-execution.

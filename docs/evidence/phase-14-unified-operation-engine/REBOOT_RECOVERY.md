# Reboot Recovery Specifications

**Phase:** 14  
**Verdict:** PASS  

## 1. System Reboot Behavior

If the host server reboots while an operation is running:
- **No Stale Processes:** Upon boot, all associated worker PIDs are naturally dead.
- **Boot Audit Trigger:** At startup (or during the first `soviez --operations` call), `soviez_ops_reconcile_all` runs.
- **State Remapping:**
  - Operations caught in non-destructive checkpoints are remapped to `resume_safe` (ready for retry / resume).
  - Destructive or database-mutating steps are remapped to `recovery_required` to block unsafe double-executions.
  - Active locks representing dead PIDs are labeled `OPERATION_LOCK_STALE`.
- **Operator Intervention:** The operator runs `soviez --operation-recover <id>` to release stale locks and restart the operations cleanly.

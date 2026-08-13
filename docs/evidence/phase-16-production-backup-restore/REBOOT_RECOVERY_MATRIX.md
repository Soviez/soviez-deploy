# Reboot recovery matrix
Backup/restore ops use Phase 14 registry checkpoints; mid-operation interrupt → `recovery_required` / reattach paths (no blind Production overwrite). Integration suite exercises operation-state interruption/reconcile.

**Gap:** full host reboot mid-dump / mid-switch / mid-rollback for every listed checkpoint was not re-executed end-to-end in this certification pass → contributes to Phase 16 **PARTIAL**.

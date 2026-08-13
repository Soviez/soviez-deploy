# Scheduler Coordination

**Phase:** 14  
**Verdict:** PASS  

## 1. Scheduler Orchestration

To prevent overlapping system actions (e.g. running retention sweeps while Let's Encrypt reloads Nginx), Phase 14 implements host-level scheduler locking inside `src/ops/scheduler.sh`:

- **Soft Coordinator Lock:** Every scheduler run begins by acquiring the `host:scheduler` lock using `soviez_ops_scheduler_lock_acquire`.
- **Sequential Execution:** The scheduler executes sequential tasks within the lock session:
  1. **SSL Audit:** Triggers Let's Encrypt certificate renewal sweeps (`soviez_ssl_monitor_apply`) across all target environments.
  2. **Retention Sweep:** Executes Stage expiration/cleanup evaluations (`soviez_retention_scheduler_scan`).
- **Resource Protection:** Underneath the soft scheduler coordinator lock, command-specific engines maintain exact-resource locks (`env:<id>`) to prevent destructive collisions.

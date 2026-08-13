# Locking and Fencing

**Phase:** 14  
**Verdict:** PASS  

## 1. Locking Implementation

Locks are managed inside `$SOVIEZ_OPS_ROOT/registry/locks/` using atomic `mkdir` commands to achieve zero-concurrency race conditions. Lock folders store a strict `owner.json` containing the PID, the operation ID, and the generation.

## 2. Fencing and Rejection Codes

- **Conflict Check:** Any lock collision with an active process returns `OPERATION_LOCK_CONFLICT`.
- **Stale Lock Guard:** If a lock is held, but the owner process is verified dead (via `kill -0`) and the heartbeat is dead (older than 300 seconds), the lock is classed as stale, and the engine triggers `OPERATION_LOCK_STALE`.
- **Safe Recoveries:** To clean up a stale lock, the operator executes `--operation-recover`, releasing the lock safely and archiving the terminated record.
- **Deadlock Prevention:** The locking manager sorts resource lists alphanumerically using `sort` prior to multi-acquire loops, eliminating cyclic dependency deadlocks.

# Scheduler Safety

This document describes the safety and coordination mechanisms implemented in the host-local scheduler.

## 1. Soft Host Scheduler Lock (`host:scheduler`)

The scheduler runs periodic background tasks, such as SSL certificate renewal scans and Stage retention sweeps. To prevent multiple scheduler instances from running concurrently and causing race conditions:

- The scheduler acquires a soft coordinator lock: `host:scheduler`.
- Lock acquisition uses atomic directory creation (`mkdir`) inside the host-isolated locks repository:
  `$SOVIEZ_OPS_ROOT/registry/locks/host:scheduler`
- If the directory creation succeeds, the scheduler runs its tasks. If it fails, the scheduler short-circuits gracefully.

## 2. Task Coordination Sequence

When the scheduler runs, it executes tasks in a strict, coordinated sequence:

1. **Acquire Lock:** Atomically acquires `host:scheduler`.
2. **SSL Monitor Apply:** Scans and applies pending SSL renewals and rotations.
3. **Retention Scan:** Scans and executes due Stage retention purges.
4. **Release Lock:** Deletes the lock directory.

## 3. Overlapping Operation Protection

While the scheduler holds the `host:scheduler` lock, any manual CLI operations that overlap with scheduled tasks (e.g., manual Stage deletion or manual SSL renewal) are coordinated. The conflict engine evaluates the active scheduler tasks and refuses manual operations that conflict with scheduled runs, preventing double-execution or resource collisions.

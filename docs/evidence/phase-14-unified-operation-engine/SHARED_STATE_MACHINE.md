# Shared State Machine Specifications

**Phase:** 14  
**Verdict:** PASS  

## 1. Lifecycle States

The 14 top-level states tracked by `src/ops/transitions.sh` are:

- `created` — Operation generated; not yet running.
- `queued` — Added to local scheduler wait queue.
- `starting` — Worker launching; initializing resources.
- `running` — Main thread executing.
- `waiting` — Paused on external action (DNS, user consent).
- `retry_scheduled` — Failure occurred; retry backoff scheduled.
- `cancel_requested` — Operator triggered cancel; awaiting boundary.
- `canceling` — Rolling back changes.
- `rollback_running` — Rolling back changes.
- `recovery_required` — Broken execution state; operator intervention required.
- `completed` — Completed successfully (Terminal).
- `canceled` — Abandoned successfully (Terminal).
- `failed_retryable` — Halted with recoverable error (Terminal).
- `failed_terminal` — Halted with permanent, irreversible error (Terminal).

## 2. Assert Transition Rules

Transitions are verified by `soviez_ops_sm_can_transition` which asserts allowed pairs (e.g., `running:waiting`, `waiting:running`, `running:cancel_requested`, etc.). Any invalid transition (e.g. going from `completed` directly to `starting`) throws `OPERATION_TRANSITION_INVALID` and exits.

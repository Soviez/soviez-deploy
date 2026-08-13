# Reconciliation Matrix

This document defines the classification rules used by the reconciliation engine to resolve stale or orphaned operations.

## 1. Reconciliation Classifications

When an operation is checked for liveness (e.g., during a system reboot or manual status query), the engine evaluates the worker process ID (PID) and heartbeat age to classify the operation's state:

| Worker PID Status | Heartbeat Age | Last Known Checkpoint | Classification | Action / Behavior |
|---|---|---|---|---|
| **Alive** | < 300 seconds | Any | **`healthy`** | No action. Operation is running normally. |
| **Dead** | < 300 seconds | Safe to resume (e.g., waiting for DNS) | **`resume_safe`** | Triggers a safe background restart of the worker. |
| **Dead** | > 300 seconds | Retryable step (e.g., transient network error) | **`retry_scheduled`** | Increments the retry counter and schedules a retry run. |
| **Dead** | > 300 seconds | Destructive step (e.g., database drop, file purge) | **`recovery_required`** | Blocks execution. Requires manual operator review and confirmation (`--yes`). |
| **Dead** | Any | Terminal state completed but index/locks held | **`cleanup_terminal_metadata`** | Archives the registry index, releases locks, and logs history. |

## 2. Safety Invariants

- **Host Identity Verification:** If the hostname of the running server does not match the `host_identity` recorded in `canonical.json`, reconciliation immediately classifies the operation as `recovery_required` to prevent cross-host corruption.
- **Fail-Closed Default:** Any ambiguous state or unclassified checkpoint defaults to `recovery_required` to ensure that no destructive actions are ever repeated automatically.

# Recovery Matrix

**Phase:** 14  
**Verdict:** PASS  

## 1. Recovery Execution Logic

The recovery manager evaluates stale locks, dead processes, and interrupted checkpoints:

| Reconcile Decision | Identified Problem | Safe Resolution | Destructive Prompt Needed |
|---|---|---|---|
| `healthy` | Process alive; matching FQDN | No action needed; report healthy. | No |
| `attach_existing` | Worker running or systemd active | Attaches to existing background stream. | No |
| `resume_safe` | Worker dead; non-destructive step | Triggers retry/restart via adapter. | No |
| `retry_scheduled` | Scheduled retry backoff | Triggers starting transition immediately. | No |
| `recovery_required` | Worker dead during destructive step | Blocked. Requires operator `--yes`. | **Yes** |
| `cleanup_terminal_metadata` | Finished state; stale index | Appends to historical log; deletes lock. | No |

Destructive recoveries prompt with `DESTRUCTIVE_CONFIRMATION_REQUIRED` unless executed with `--yes`.

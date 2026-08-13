# Cancellation Matrix

**Phase:** 14  
**Verdict:** PASS  

## 1. Cancellation Boundary Rules

`src/ops/cancellation.sh` enforces distinct cancellation capabilities per checkpoint:

| Operation Type | Active Checkpoint | Cancellation Mode | Outcome / Response |
|---|---|---|---|
| `stage_create` | `database_restore` | **irreversible** | Rejects cancel; `OPERATION_CANCEL_NOT_ALLOWED`. |
| `retention_delete`| `delete_*` | **irreversible** | Rejects cancel; `OPERATION_CANCEL_NOT_ALLOWED`. |
| `new` | `tenant_identity_created` | **irreversible** | Rejects cancel; `OPERATION_CANCEL_NOT_ALLOWED`. |
| `ssl_renewal` | `promote_*` | **rollback** | Transitions to `canceling` → triggers rollback sequence. |
| `stage_create` | `nginx_*` | **rollback** | Transitions to `canceling` → triggers rollback sequence. |
| `stage_create` | `creating_directories` | **cancelable** | Instant transition to `canceled`. |
| `ssl_renewal` | `waiting_for_dns` | **cancelable** | Instant transition to `canceled`. |

Rollback cancellation requests require `--yes` confirmation or throw `OPERATION_CANCEL_REQUIRES_CONFIRMATION`.

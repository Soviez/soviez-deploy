# REPLAY_AND_IDEMPOTENCY — Phase 10.5

| Mechanism | Behavior |
|-----------|----------|
| Authorize idempotency | Same key → same auth; conflict → `IDEMPOTENCY_CONFLICT` |
| Online consume | One-use; replay → `TICKET_ALREADY_CONSUMED` |
| Offline ledger | Hash + (operation_id, stage_id); reuse → `OFFLINE_PACKAGE_ALREADY_USED` |
| Ticket `exp` | Blocks START only |
| Revoke unused | `TICKET_REVOKED` |

**Tests:** _(parent fills)_

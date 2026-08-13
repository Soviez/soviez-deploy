# Pull session lifecycle — Phase 7

## States

```
                    ┌──────────┐
                    │ pending  │ (initial default; create → active immediately)
                    └────┬─────┘
                         │
                         ▼
                    ┌──────────┐
         ┌─────────│  active  │─────────┐
         │         └────┬─────┘         │
         │              │               │
         ▼              ▼               ▼
   ┌──────────┐  ┌──────────┐    ┌──────────┐
   │ revoked  │  │completed │    │ expired  │
   └──────────┘  └──────────┘    └──────────┘
         │                              │
         └──────────┬───────────────────┘
                    ▼
              denied / failed
```

## Transitions

| Event | From | To | Side effects |
|-------|------|-----|--------------|
| Create | — | `active` | Issue credentials; append `created` event |
| Idempotent recreate | `active` | `active` | Re-issue credentials; same session id |
| Refresh | `active` | `active` | New ticket; increment `refresh_count` |
| Complete | `active` | `completed` | Clear token hashes; append `completed` |
| Revoke | `active` | `revoked` | Clear token hashes; append `revoked` |
| Max lifetime | `active` | `expired` | On refresh attempt after `max_lifetime_at` |
| Denied create (revoked idem) | terminal | — | No reopen |

## Timers

| Timer | Value | Enforced at |
|-------|-------|-------------|
| Credential TTL | 15 min | Ticket `exp`; gateway |
| Max session lifetime | 1 h | SaaS refresh |
| Max refresh count | 5 | SaaS refresh |

## Idempotency

- **Create:** `(account_id, idempotency_key)` unique; same key + same request hash → re-issue credentials
- **Create conflict:** same key + different request hash → `IDEMPOTENCY_CONFLICT`
- **Refresh:** metadata `last_refresh_idempotency_key` for repeat refresh without count bump

## Events (append-only)

| event_type | actor_type | When |
|------------|------------|------|
| `created` | `device` | Session insert |
| `refreshed` | `device` | Successful refresh |
| `completed` | `device` | Complete API |
| `revoked` | `device` | Revoke API |

## Gateway correlation

Ticket claim `session_id` seeds in-memory digest graph. Gateway does not call SaaS per request.

## Tests

- DB certification: session insert, idempotency, cross-account denial
- Unit: refresh limit, max lifetime, completed/revoked guards

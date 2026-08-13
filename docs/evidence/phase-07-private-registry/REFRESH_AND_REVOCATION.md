# Refresh and revocation — Phase 7

## Refresh API

**Route:** `POST /api/installer/registry/pull-sessions/refresh`

### Preconditions

| Check | Denial code |
|-------|-------------|
| Session exists for account | `PULL_SESSION_NOT_FOUND` |
| Device matches | `DEVICE_AUTH_REQUIRED` |
| Operation id matches | `OPERATION_NOT_AUTHORIZED` |
| Not revoked | `PULL_SESSION_REVOKED` |
| Not completed | `PULL_SESSION_COMPLETED` |
| Within max lifetime (1 h) | `MAX_SESSION_AGE_EXCEEDED` |
| Refresh count < 5 | `REFRESH_LIMIT_EXCEEDED` |
| Capability still allowed | `CAPABILITY_REQUIRED` |
| Release still approved/published | `RELEASE_*` codes |
| Optional digest/release_id match session | `DIGEST_NOT_APPROVED` |

### Behavior

- Issues new `client_token` + `pull_ticket`
- Updates `active_ticket_jti_hash`, `client_token_hash`, `expires_at`
- Increments `refresh_count` (unless idempotent refresh key matches)
- Appends `refreshed` event

### Idempotent refresh

Same `idempotency_key` as stored in session metadata → re-issue credentials without incrementing count.

## Revoke API

**Route:** `POST /api/installer/registry/pull-sessions/revoke`

- Sets `status = revoked`, `revoked_at`, `denial_reason`
- Clears `client_token_hash`, `active_ticket_jti_hash`
- Idempotent if already revoked
- Appends `revoked` event

## Complete API

**Route:** `POST /api/installer/registry/pull-sessions/complete`

- Sets `status = completed`, `completed_at`
- Clears credential hashes
- Idempotent if already completed
- Appends `completed` event

## Gateway-side expiry

Even without SaaS revoke:

- Ticket `exp` enforced offline at gateway
- Returns `PULL_SESSION_EXPIRED`

## Operational guidance

| Situation | Recommended action |
|-----------|-------------------|
| Pull succeeded | `complete` |
| Pull failed mid-stream | `revoke` |
| Ticket expired during large pull | `refresh` (if within limits) then resume |
| Compromised temp config | `revoke` immediately |

## Tests

- Unit: refresh limit, max lifetime, completed guard
- DB: session state transitions in certification harness

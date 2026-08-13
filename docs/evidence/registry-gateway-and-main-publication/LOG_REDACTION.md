# LOG_REDACTION — Gateway Logging Hygiene

## Verdict

**PASS** (unit test)

## Implementation

**File:** `soviez-sh/services/registry-gateway/src/redact.ts`

### Redacted patterns

| Pattern | Replacement |
|---------|-------------|
| `Bearer <token>` | `Bearer [REDACTED]` |
| `SOVIEZ_UPSTREAM_REGISTRY_TOKEN=…` | `SOVIEZ_UPSTREAM_REGISTRY_TOKEN=[REDACTED]` |
| `SOVIEZ_UPSTREAM_REGISTRY_USER=…` | `SOVIEZ_UPSTREAM_REGISTRY_USER=[REDACTED]` |
| `password=…` | `password=[REDACTED]` |
| JOSE-like `eyJ…` tokens | key=[REDACTED] |

### Safe logging entry points

| Function | Use |
|----------|-----|
| `safeLog()` | Standard info logging |
| `safeError()` | Error logging |
| `redactSecrets()` | String sanitization |

Server uses `safeLog` for startup and operational messages (`src/server.ts`).

## Test evidence

**Case:** `"secrets absent from logs"` in `test/gateway.test.ts`

1. Capture `console.log` / `console.error` during manifest + blob operations.
2. Assert combined output does not contain upstream secret fixture.
3. Assert combined output does not contain valid pull ticket.

**Result:** PASS

## Edge proxy guidance

`docs/SECURITY.md` recommends omitting `Authorization` headers from nginx access logs at the edge. Production nginx config should be reviewed post-provision: **PENDING**

## Operational requirement

Operators must not enable debug logging that bypasses `safeLog`/`safeError` in production without redaction review.

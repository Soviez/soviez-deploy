# TOKEN_EXPIRY_TEST — Pull Ticket Expiration

## Verdict

**PASS**

## Policy

| Parameter | Value |
|-----------|------:|
| Ticket TTL (`PULL_CREDENTIAL_TTL_SECONDS`) | 900 |
| Session max (`PULL_SESSION_MAX_LIFETIME_SECONDS`) | 3600 |

Gateway enforces per-ticket `exp` claim at verification time.

## Test: expired ticket denied

**File:** `soviez-sh/services/registry-gateway/test/gateway.test.ts`  
**Case:** `"expired ticket denied"`

### Setup

- Issue ticket with `iat: now - 3600`, `exp: now - 60`
- Request manifest with `Authorization: Bearer <expired>`

### Expected

| Field | Value |
|-------|-------|
| HTTP status | 401 |
| Denial code | `PULL_SESSION_EXPIRED` |

### Result

**PASS**

## Test: valid ticket within TTL

**Case:** `"valid ticket allows manifest and blobs"`

- Ticket issued with `exp: now + 900`
- Manifest + config blob + layer blob all return 200

### Result

**PASS**

## SaaS-side enforcement

Session max lifetime and refresh count enforced at issuance in `soviez-saas/src/lib/registry/service.ts` (3600s / 5 refreshes). Gateway offline verify covers ticket-level expiry independently.

## Live staging verification

Post-push test against staging SaaS issuing real tickets: **PENDING**

# Upstream simulation — Phase 7

## Approach

Gateway tests do **not** require live Docker Hub connectivity.

## Mock upstream

File: `services/registry-gateway/src/mock-upstream.ts`

- Lightweight HTTP server serving fixture manifest + blob responses
- Activated via `SOVIEZ_UPSTREAM_BASE_URL` env override in tests
- Supports GET/HEAD for `/v2/{repo}/manifests/{digest}` and `/v2/{repo}/blobs/{digest}`

## Test scenarios (`gateway.test.ts`)

| Scenario | Verified |
|----------|----------|
| Health endpoints | 200 OK |
| `/v2/` without auth | 401 + WWW-Authenticate |
| Valid ticket on `/v2/` | 200 |
| Manifest fetch + graph ingest | 200 + downstream blob allowed |
| Unauthorized blob digest | 403 BLOB_SCOPE_DENIED |
| Wrong repository | 403 REPOSITORY_SCOPE_DENIED |
| Catalog denied | 403 METHOD_NOT_ALLOWED |
| Tags list denied | 403 METHOD_NOT_ALLOWED |
| Write methods denied | 405 METHOD_NOT_ALLOWED |
| Expired ticket | 401 PULL_SESSION_EXPIRED |
| Invalid signature | 401 SIGNATURE_INVALID |
| Token exchange `/auth/token` | 200 with expires_in |
| Upstream unavailable | 502 UPSTREAM_UNAVAILABLE |

## SaaS layer

- Unit tests (`logic.test.ts`) — pure crypto/catalog logic; no network
- DB certification (`certification.test.ts`) — isolated Postgres via Docker harness; no Hub

## Production upstream

Gateway production config:

- Host: `registry-1.docker.io` (default)
- Auth: Basic with pull-only Hub credentials
- Streaming proxy — no full-buffer except manifest JSON (small)

## Explicit non-test

Live Hub pull against private repo cutover — deferred to owner-approved deployment phase.

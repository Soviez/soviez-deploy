# Gateway protocol — Phase 7

**Service:** `soviez-sh/services/registry-gateway/`  
**Package tests:** 14/14 pass

## Authentication flow

1. Client sends `Authorization: Bearer <pull_ticket>` on OCI requests.
2. Gateway parses bearer token.
3. `verifyRegistryPullTicket(token, publicKeysById)` — offline Ed25519.
4. On success: seed `SessionGraphCache` with `session_id` + manifest digest.
5. Optional: `GET /auth/token` exchanges verified ticket for Docker bearer token metadata.

## Endpoints

| Method | Path | Status | Code on deny |
|--------|------|--------|--------------|
| GET | `/health`, `/ready` | 200 | — |
| GET | `/v2/` | 200 / 401 | `WWW-Authenticate` challenge |
| GET | `/auth/token` | 200 / 401 | `SIGNATURE_INVALID`, `PULL_SESSION_EXPIRED`, etc. |
| GET/HEAD | `/v2/{repo}/manifests/{ref}` | 200 / 403 / 401 | `REPOSITORY_SCOPE_DENIED`, `BLOB_SCOPE_DENIED` |
| GET/HEAD | `/v2/{repo}/blobs/{digest}` | stream / 403 | `BLOB_SCOPE_DENIED` |
| GET | `/v2/_catalog` | 403 | `METHOD_NOT_ALLOWED` |
| GET | `*/tags/list` | 403 | `METHOD_NOT_ALLOWED` |
| PUT/POST/PATCH/DELETE | any | 405 | `METHOD_NOT_ALLOWED` |

## Error body

```json
{ "code": "DENIAL_CODE", "message": "human readable" }
```

## Manifest handling

- GET manifest: fetch upstream body (small), `ingestManifest` to add config/layer digests to graph, return body to client
- HEAD manifest: proxy upstream headers only

## Blob handling

- Stream via `pipeline(upstreamRes, clientRes)`
- Forward Range, Accept, If-None-Match
- Preserve Content-Length, Content-Range, docker-content-digest

## Mock upstream

Tests use `mock-upstream.ts` + `SOVIEZ_UPSTREAM_BASE_URL` override — no live Hub required.

## Configuration

See `services/registry-gateway/README.md` and `src/config.ts`.

## Health

Independent of SaaS availability — gateway runs with only public keys + upstream creds.

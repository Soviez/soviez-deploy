# OCI request matrix — Phase 7

## Authorized pull sequence (happy path)

| Step | Client request | Gateway action | Upstream |
|------|----------------|----------------|----------|
| 1 | `GET /v2/` + Bearer ticket | Verify ticket; 200 | — |
| 2 | `GET /auth/token` + Bearer | Token exchange JSON | — |
| 3 | `GET /v2/soviez/soviez-erp/manifests/sha256:ROOT` | Verify repo+digest; fetch manifest; ingest graph | Hub GET manifest |
| 4 | `GET /v2/soviez/soviez-erp/blobs/sha256:LAYER1` | Verify digest in graph; stream | Hub GET blob |
| 5 | `GET /v2/soviez/soviez-erp/blobs/sha256:CONFIG` | Verify digest in graph; stream | Hub GET blob |
| 6 | (optional) HEAD manifest/blob | Same auth checks | Hub HEAD |

## Denied requests

| Request | Expected code |
|---------|---------------|
| No Authorization header | 401 `INVALID_REQUEST` |
| Expired ticket | 401 `PULL_SESSION_EXPIRED` |
| Bad signature | 401 `SIGNATURE_INVALID` |
| Wrong repository | 403 `REPOSITORY_SCOPE_DENIED` |
| Manifest tag `latest` not matching ticket digest | 403 `BLOB_SCOPE_DENIED` |
| Blob digest not in graph | 403 `BLOB_SCOPE_DENIED` |
| `GET /v2/_catalog` | 403 `METHOD_NOT_ALLOWED` |
| `GET …/tags/list` | 403 `METHOD_NOT_ALLOWED` |
| `PUT /v2/…/blobs/…` | 405 `METHOD_NOT_ALLOWED` |
| Upstream 404/502 | 404/502 `UPSTREAM_UNAVAILABLE` |

## Range requests

| Client header | Gateway behavior |
|---------------|------------------|
| `Range: bytes=0-1048575` | Forward to upstream; preserve `206` + `Content-Range` |

## Repository normalization

- Strip leading/trailing slashes
- Case-sensitive match against ticket `repository`

## Digest normalization

- Accept `sha256:hex` or bare 64-hex → prefix `sha256:`

## Test coverage

`services/registry-gateway/test/gateway.test.ts` — 14 tests covering auth, scope, graph, upstream mock, method denial.

# SCOPE_ENFORCEMENT — Repository, Digest, and Operation Scope

## Verdict

**PASS** (gateway unit tests)

## Allowed scope

| Dimension | Allowed value |
|-----------|---------------|
| Repository | `soviez/soviez-erp` (ticket-bound; mock uses test repo in unit tests) |
| Operation | `pull` only |
| Digest | Ticket root manifest digest + derived graph digests only |

## Test matrix

| Test case | Expected code | HTTP | Result |
|-----------|---------------|------|--------|
| Valid repo + digest + blobs | — | 200 | PASS |
| Wrong repository | `REPOSITORY_SCOPE_DENIED` | 403 | PASS |
| Wrong manifest digest | `BLOB_SCOPE_DENIED` | 403 | PASS |
| Unauthorized blob digest | `BLOB_SCOPE_DENIED` | 403 | PASS |
| Push (PUT manifest) | `METHOD_NOT_ALLOWED` | 405 | PASS |
| Push scope at token endpoint | `METHOD_NOT_ALLOWED` | 403 | PASS |
| Catalog list | `METHOD_NOT_ALLOWED` | 403 | PASS |
| Tags list | denied | 403 | PASS |
| Wrong service/audience | `AUDIENCE_DENIED` | 403 | PASS |
| Wrong account header | `LICENSE_BINDING_DENIED` | 403 | PASS |
| Wrong device header | `DEVICE_BINDING_DENIED` | 403 | PASS |
| Unauthenticated manifest | — | 401 | PASS |

## Digest graph enforcement

1. Authorized manifest fetch populates session digest graph (`src/graph.ts`).
2. Subsequent blob requests must match a digest in that graph.
3. Arbitrary digest (e.g. `sha256:deadbeef…`) denied even with valid ticket.

## SaaS allowlist alignment

`REGISTRY_REPOSITORY_ALLOWLIST` in `soviez-saas/src/lib/registry/constants.ts`:

```typescript
["soviez/soviez-erp"]
```

Gateway does not maintain a separate repo list beyond ticket claim verification — issuer must bind correct repository.

## Live cross-repo verification

Installer pull against staging gateway with SaaS-issued ticket for production digest: **PENDING**

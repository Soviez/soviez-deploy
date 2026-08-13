# REGISTRY_TOKEN_CONTRACT — Pull Ticket Specification

## Overview

Short-lived, pull-only credential verified **offline** by the registry gateway. Uses dedicated Ed25519 signing domain — separate from Device Auth, License, and release-manifest keys.

## Format

**Not JOSE JWT.** Custom two-part token:

```
<base64url(canonical_json_claims)>.<base64url(ed25519_signature)>
```

Signing input:

```
soviez.registry-pull-ticket.v1\n<canonical_json>
```

Canonical JSON: keys sorted recursively (`canonicalJson` in both SaaS and gateway).

## Claims schema

| Claim | Type | Required | Description |
|-------|------|----------|-------------|
| `typ` | string | yes | Always `soviez.registry-pull-ticket.v1` |
| `jti` | string | yes | Unique ticket id (base64url random) |
| `session_id` | string | yes | Pull session id; Docker Basic username |
| `account_id` | string | yes | License/account binding |
| `device_id` | string | yes | Device binding |
| `operation_id` | string | yes | Stage operation correlation |
| `repository` | string | yes | OCI repo (allowlist: `soviez/soviez-erp`) |
| `digest` | string | yes | Root manifest digest (sha256:…) |
| `architecture` | string | yes | e.g. `amd64` |
| `scope` | string | yes | Always `pull` |
| `iat` | number | yes | Issued-at (unix seconds) |
| `exp` | number | yes | Expiry (unix seconds); max TTL **900s** from issuance policy |
| `signer_key_id` | string | yes | Key id prefix `rtk_` + hash fragment |

## Verification outcomes

| Result | HTTP | Code |
|--------|------|------|
| Valid | 200 | — |
| Malformed / bad sig | 401 | various |
| Unknown key | 401 | — |
| Expired | 401 | `PULL_SESSION_EXPIRED` |
| Wrong repo | 403 | `REPOSITORY_SCOPE_DENIED` |
| Wrong digest | 403 | `BLOB_SCOPE_DENIED` |
| Blob not in graph | 403 | `BLOB_SCOPE_DENIED` |
| Account mismatch | 403 | `LICENSE_BINDING_DENIED` |
| Device mismatch | 403 | `DEVICE_BINDING_DENIED` |

## Session lifetime (SaaS policy)

| Bound | Seconds |
|-------|--------:|
| Single ticket TTL | 900 |
| Max session lifetime | 3600 |
| Max refresh count | 5 |

Gateway verifies per-ticket `exp`; session max enforced at SaaS issuance/refresh.

## Public key configuration (gateway)

Env: `SOVIEZ_REGISTRY_TICKET_PUBLIC_KEYS_JSON`

```json
{ "rtk_<id>": "<raw ed25519 pubkey base64url>" }
```

## Implementations (must stay aligned)

| Component | Path |
|-----------|------|
| Issuer | `soviez-saas/src/lib/registry/ticket.ts` |
| Verifier | `soviez-sh/services/registry-gateway/src/ticket.ts` |
| SaaS tests | `soviez-saas/src/lib/registry/logic.test.ts` |
| Gateway tests | `soviez-sh/services/registry-gateway/test/gateway.test.ts` |

## Test evidence

| Test | Result |
|------|--------|
| Valid ticket manifest + blobs | PASS |
| Expired ticket | PASS (`TOKEN_EXPIRY_TEST.md`) |
| Wrong repo / digest / blob | PASS (`SCOPE_ENFORCEMENT.md`) |

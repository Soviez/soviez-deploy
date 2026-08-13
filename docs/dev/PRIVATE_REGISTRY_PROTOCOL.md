# Private Registry Protocol (implementer)

**Protocol version:** `registry-pull/v1`  
**Pull ticket domain:** `soviez.registry-pull-ticket.v1`  
**Release manifest domain:** `soviez.release-manifest.v1`  
**Offline bundle format:** `offline-image-bundle/v1`

No real secrets in this document.

---

## 1. Database schemas

### 1.1 `registry_releases`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID PK | |
| `product_code` | TEXT | Default `soviez-erp` |
| `release_version` | TEXT | Human version string |
| `channel` | TEXT | Default `stable` |
| `oci_repository` | TEXT | e.g. `soviez/soviez-erp` |
| `manifest_digest` | TEXT | `sha256:[64 hex]` — **authoritative** |
| `display_tag` | TEXT | Optional display only |
| `architecture` | TEXT | e.g. `linux/amd64` |
| `platform_os` | TEXT | Default `linux` |
| `platform_arch` | TEXT | Default `amd64` |
| `is_index` | BOOLEAN | Multi-arch index flag |
| `image_size_bytes` | BIGINT | Optional |
| `build_at` | TIMESTAMPTZ | Optional |
| `published_at` | TIMESTAMPTZ | |
| `status` | TEXT | `draft\|candidate\|approved\|published\|withdrawn\|revoked` |
| `min_installer_version` | TEXT | Optional |
| `min_erp_version` | TEXT | Optional |
| `release_manifest_version` | TEXT | Default `release-manifest/v1` |
| `signed_manifest_json` | JSONB | Cached signed manifest |
| `signer_key_id` | TEXT | Release manifest key id |
| `source_ci_ref` | TEXT | CI git SHA |
| `metadata` | JSONB | |
| `created_at`, `updated_at` | TIMESTAMPTZ | |

**Unique:** `(product_code, release_version, channel, architecture)`

**Resolvable statuses:** `approved`, `published`

### 1.2 `registry_pull_sessions`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID PK | Also used as `registry_username` for docker login |
| `account_id` | UUID FK → profiles | |
| `device_id` | UUID FK → cli_devices | |
| `operation_id` | TEXT | Caller-supplied operation correlation |
| `operation_type` | TEXT | Allowlisted operation |
| `capability_code` | TEXT | Default `private_image_pull` |
| `capability_decision` | JSONB | Resolver snapshot |
| `release_id` | UUID FK → registry_releases | |
| `oci_repository` | TEXT | Bound repository |
| `authorized_digest` | TEXT | Bound manifest digest |
| `architecture` | TEXT | |
| `status` | TEXT | See lifecycle |
| `protocol_version` | TEXT | `registry-pull/v1` |
| `idempotency_key` | TEXT | Per-account unique |
| `request_hash` | TEXT | Payload hash for idempotency |
| `client_token_hash` | TEXT | Hashed opaque token |
| `active_ticket_jti_hash` | TEXT | Current ticket jti hash |
| `refresh_count` | INT | Default 0 |
| `request_count` | INT | Default 0 |
| `max_refresh_count` | INT | Default 5 |
| `created_at` | TIMESTAMPTZ | |
| `expires_at` | TIMESTAMPTZ | Credential expiry |
| `max_lifetime_at` | TIMESTAMPTZ | Session ceiling (1 h) |
| `first_used_at`, `last_used_at` | TIMESTAMPTZ | |
| `revoked_at`, `completed_at` | TIMESTAMPTZ | |
| `denial_reason` | TEXT | |
| `metadata` | JSONB | Refresh idempotency keys |
| `updated_at` | TIMESTAMPTZ | |

**Unique:** `(account_id, idempotency_key)`

**Statuses:** `pending`, `active`, `completed`, `expired`, `revoked`, `denied`, `failed`

### 1.3 `registry_pull_session_events`

| Column | Type | Notes |
|--------|------|-------|
| `id` | UUID PK | |
| `session_id` | UUID FK | ON DELETE CASCADE |
| `event_type` | TEXT | e.g. `created`, `refreshed`, `completed`, `revoked` |
| `actor_type` | TEXT | `device\|account\|system\|admin\|gateway\|cleanup` |
| `actor_account_id` | UUID | Optional |
| `actor_device_id` | UUID | Optional |
| `reason_code` | TEXT | Optional |
| `metadata` | JSONB | |
| `created_at` | TIMESTAMPTZ | |

**Immutable:** UPDATE/DELETE forbidden by trigger.

---

## 2. SaaS APIs (Device PoP required)

All routes: `runtime = nodejs`. Auth via `requireDeviceSignedRequest(request, PATH)`.

### 2.1 POST `/api/installer/registry/releases/resolve`

Resolve an approved/published release and return signed manifest.

**Request body (JSON):**

| Field | Required | Notes |
|-------|----------|-------|
| `operation_id` | Yes | |
| `operation_type` | No | Default `test_foundation` |
| `release_id` | One of | UUID |
| `release_version` + `channel` | One of | Version lookup |
| *(neither)* | | Latest published in channel |
| `architecture` | No | Default `linux/amd64` |
| `product_code` | No | Default `soviez-erp` |
| `protocol_version` | No | |

**Success 200:**

```json
{
  "release_id": "uuid",
  "release_version": "18.0.1.01.0",
  "repository": "soviez/soviez-erp",
  "digest": "sha256:…",
  "architecture": "linux/amd64",
  "channel": "stable",
  "min_installer_version": "1.0.0",
  "signed_release_manifest": {
    "payload": { "type": "soviez.release-manifest.v1", "…": "…" },
    "signature_b64url": "…",
    "signer_key_id": "rmk_…"
  },
  "compatibility": { "…": "…" },
  "note": "Immutable digest is authoritative. No upstream registry credentials are returned."
}
```

### 2.2 POST `/api/installer/registry/pull-sessions`

Create (or idempotently re-open) a pull session.

**Request body:**

| Field | Required |
|-------|----------|
| `release_id` | Yes |
| `operation_id` | Yes |
| `operation_type` | No |
| `idempotency_key` | Yes |
| `architecture` | No |

**Success 200:**

```json
{
  "pull_session_id": "uuid",
  "status": "active",
  "repository": "soviez/soviez-erp",
  "digest": "sha256:…",
  "architecture": "linux/amd64",
  "expires_at": "ISO8601",
  "max_lifetime_at": "ISO8601",
  "gateway_url": "https://registry.soviez.local",
  "registry_username": "uuid",
  "client_token": "sovpull_…",
  "pull_ticket": "base64url.canonical.base64url.sig",
  "idempotent": false,
  "scope": "pull",
  "note": "Short-lived pull-only credential. …"
}
```

### 2.3 POST `/api/installer/registry/pull-sessions/refresh`

**Request body:** `session_id`, `operation_id`, `idempotency_key`; optional `release_id`, `digest` (must match session if provided).

**Success 200:** `session_id`, `expires_at`, `client_token`, `pull_ticket`, `refresh_count`, `idempotent`.

### 2.4 POST `/api/installer/registry/pull-sessions/complete`

**Request body:** `session_id`, `idempotency_key`.

**Success 200:** `session_id`, `status: "completed"`, `idempotent`.

### 2.5 POST `/api/installer/registry/pull-sessions/revoke`

**Request body:** `session_id`; optional `reason`.

**Success 200:** `session_id`, `status: "revoked"`, `idempotent`.

---

## 3. Denial codes

Stable JSON error field: `{ "error": "<CODE>" }`

| Code | Typical HTTP | Source |
|------|--------------|--------|
| `DEVICE_AUTH_REQUIRED` | 401/403 | Device gate |
| `DEVICE_REVOKED` | 403 | Device gate |
| `CAPABILITY_REQUIRED` | 403 | Entitlement resolver |
| `OPERATION_NOT_AUTHORIZED` | 403 | Operation type / session state |
| `RELEASE_NOT_FOUND` | 404 | Catalog |
| `RELEASE_NOT_APPROVED` | 403 | Status draft/candidate |
| `RELEASE_WITHDRAWN` | 403 | Status withdrawn |
| `RELEASE_REVOKED` | 403 | Status revoked |
| `ARCHITECTURE_NOT_SUPPORTED` | 403 | Arch mismatch |
| `DIGEST_INVALID` | 400 | Format |
| `DIGEST_NOT_APPROVED` | 403 | Refresh digest mismatch |
| `PULL_SESSION_NOT_FOUND` | 404 | |
| `PULL_SESSION_EXPIRED` | 401/403 | Gateway ticket TTL |
| `PULL_SESSION_REVOKED` | 403 | |
| `PULL_SESSION_COMPLETED` | 409 | Refresh on completed |
| `IDEMPOTENCY_CONFLICT` | 409 | Same key, different payload |
| `REFRESH_LIMIT_EXCEEDED` | 403 | > 5 refreshes |
| `MAX_SESSION_AGE_EXCEEDED` | 403 | > 1 h lifetime |
| `REPOSITORY_SCOPE_DENIED` | 403 | Repo not in ticket / allowlist |
| `BLOB_SCOPE_DENIED` | 403 | Digest not in session graph |
| `METHOD_NOT_ALLOWED` | 403/405 | Push/catalog/tags |
| `UPSTREAM_UNAVAILABLE` | 502/404 | Hub fetch failure |
| `SIGNATURE_INVALID` | 401 | Ticket/manifest crypto |
| `MANIFEST_TAMPERED` | — | Reserved verifier code |
| `INVALID_REQUEST` | 400/404 | Malformed |
| `INTERNAL_ERROR` | 500 | |

Gateway emits subset: `REPOSITORY_SCOPE_DENIED`, `BLOB_SCOPE_DENIED`, `METHOD_NOT_ALLOWED`, `UPSTREAM_UNAVAILABLE`, `SIGNATURE_INVALID`, `PULL_SESSION_EXPIRED`, `INVALID_REQUEST`, `INTERNAL_ERROR`.

---

## 4. Pull ticket format

**Token:** `base64url(canonical_json_claims).base64url(ed25519_signature)`

**Signed bytes:** `"soviez.registry-pull-ticket.v1\n" + canonical_json`

**Claims:**

```json
{
  "typ": "soviez.registry-pull-ticket.v1",
  "jti": "base64url随机",
  "session_id": "uuid",
  "account_id": "uuid",
  "device_id": "uuid",
  "operation_id": "string",
  "repository": "soviez/soviez-erp",
  "digest": "sha256:…",
  "architecture": "linux/amd64",
  "scope": "pull",
  "iat": 1234567890,
  "exp": 1234568790,
  "signer_key_id": "rtk_…"
}
```

Canonical JSON: recursively sorted object keys.

**Constants:**

| Constant | Value |
|----------|-------|
| `PULL_CREDENTIAL_TTL_SECONDS` | 900 (15 min) |
| `PULL_SESSION_MAX_LIFETIME_SECONDS` | 3600 (1 h) |
| `PULL_SESSION_MAX_REFRESH_COUNT` | 5 |

---

## 5. Signed release manifest

**Payload type:** `soviez.release-manifest.v1`  
**Signing domain:** `soviez.release-manifest.v1\n` + canonical JSON

**SignedReleaseManifest structure:**

```json
{
  "payload": { "type": "soviez.release-manifest.v1", "digest": "sha256:…", "…": "…" },
  "canonical": "{…}",
  "signature_b64url": "…",
  "signer_key_id": "rmk_…"
}
```

Must not sign `:latest`. Digest regex enforced.

---

## 6. Gateway contracts

Base: configurable `SOVIEZ_REGISTRY_GATEWAY_URL` (default `https://registry.soviez.local`).

| Method | Path | Auth | Behavior |
|--------|------|------|----------|
| GET | `/health`, `/ready` | None | `{ "status": "ok" }` |
| GET | `/v2/` | Bearer ticket | 200 or 401 + `WWW-Authenticate` |
| GET | `/auth/token` | Bearer ticket | Token exchange `{ token, expires_in, issued_at }` |
| GET/HEAD | `/v2/{repo}/manifests/{digest}` | Bearer ticket | Authorized manifest only; ingests graph |
| GET/HEAD | `/v2/{repo}/blobs/{digest}` | Bearer ticket | Authorized blob graph only; streams |
| GET | `/v2/_catalog` | — | 403 `METHOD_NOT_ALLOWED` |
| GET | `…/tags/list` | — | 403 |
| PUT/POST/PATCH/DELETE | any | — | 405 |

**Docker login contract:**

- Registry host: gateway URL host
- Username: `pull_session_id` (UUID)
- Password: `pull_ticket` (Ed25519 token)

Gateway verifies ticket offline via `SOVIEZ_REGISTRY_TICKET_PUBLIC_KEYS_JSON`.

**Upstream:** `SOVIEZ_UPSTREAM_REGISTRY_HOST` (default `registry-1.docker.io`), Basic auth with `SOVIEZ_UPSTREAM_REGISTRY_USER` + `SOVIEZ_UPSTREAM_REGISTRY_TOKEN`.

---

## 7. OCI pull flow

```
1. Client → SaaS: resolve (get digest + signed manifest)
2. Client → SaaS: create pull-session (get pull_ticket, client_token, gateway_url)
3. Client: docker --config "$TMPCFG" login gateway -u SESSION_ID -p PULL_TICKET
4. Client: docker --config "$TMPCFG" pull REPO@DIGEST
5. Gateway: verify ticket → fetch manifest from Hub → build session digest graph
6. Gateway: stream authorized blobs (Range-aware)
7. Client: verify local digest matches authorized
8. Client: docker logout; rm -rf "$TMPCFG"
9. Client → SaaS: complete (or revoke on failure)
```

**Repo/digest enforcement:**

- Ticket `repository` must match request path (normalized)
- Manifest reference must equal ticket `digest`
- Blob digest must appear in session graph (manifest config + layers)

**Blob graph cache:** In-memory only (`SessionGraphCache`), keyed by `session_id`. Not persisted. Lost on gateway restart (client re-fetches manifest).

---

## 8. Temporary docker `--config` contract

```bash
TMPCFG=$(mktemp -d)
trap 'docker --config "$TMPCFG" logout "$GATEWAY_HOST" 2>/dev/null; rm -rf "$TMPCFG"' EXIT

docker --config "$TMPCFG" login "$GATEWAY_HOST" \
  -u "$PULL_SESSION_ID" \
  --password-stdin <<<"$PULL_TICKET"

docker --config "$TMPCFG" pull "${REPOSITORY}@${DIGEST}"

# Local digest verification (required — no :latest fallback)
OBS=$(docker --config "$TMPCFG" image inspect \
  --format '{{index .RepoDigests 0}}' "${REPOSITORY}@${DIGEST}")
# Parse @sha256:… from OBS; MUST equal DIGEST
```

**Never** store Hub org tokens on disk. **Never** reuse temp config across operations.

---

## 9. Local digest verify commands

| Step | Command |
|------|---------|
| Pull | `docker --config "$TMPCFG" pull "${REPO}@${DIGEST}"` |
| Single-arch inspect | `docker image inspect --format '{{index .RepoDigests 0}}' "${REPO}@${DIGEST}"` |
| Multi-arch index | `docker buildx imagetools inspect "${REPO}@${INDEX_DIGEST}"` |

Parser helpers: `src/lib/registry/digest-verify.ts` — `parseRepoDigestLine`, `parseImagetoolsInspect`, `assertLocalDigestMatchesAuthorized`.

**Contract:** observed digest MUST equal session authorized digest. Mismatch → fail closed.

---

## 10. Offline bundle format

**Format version:** `offline-image-bundle/v1`

```json
{
  "format_version": "offline-image-bundle/v1",
  "product_code": "soviez-erp",
  "release_id": "uuid",
  "release_version": "18.0.1.01.0",
  "channel": "stable",
  "repository": "soviez/soviez-erp",
  "digest": "sha256:…",
  "architecture": "linux/amd64",
  "archive_format": "oci-layout | docker-archive",
  "archive_checksum_sha256": "hex",
  "archive_relative_path": "soviez-erp.oci.tar",
  "signed_release_manifest": {
    "payload": { "…": "…" },
    "signature_b64url": "…"
  },
  "signer_key_id": "rmk_…",
  "min_installer_version": "1.0.0",
  "entitlement_package_ref": null,
  "created_at": "ISO8601"
}
```

Verify with `verifyOfflineBundleManifest(publicKeys, optional archive bytes)`.

---

## 11. Environment variables

| Variable | Component | Purpose |
|----------|-----------|---------|
| `SOVIEZ_REGISTRY_GATEWAY_URL` | SaaS | Gateway URL returned to clients |
| `SOVIEZ_REGISTRY_TICKET_PRIVATE_KEY` | SaaS | Issue pull tickets |
| `SOVIEZ_REGISTRY_TICKET_PUBLIC_KEY` | SaaS / Gateway | Verify tickets |
| `SOVIEZ_RELEASE_MANIFEST_PRIVATE_KEY` | SaaS | Sign release manifests |
| `SOVIEZ_RELEASE_MANIFEST_PUBLIC_KEYS_JSON` | SaaS / Installer | Verify manifests |
| `SOVIEZ_UPSTREAM_REGISTRY_*` | Gateway only | Hub pull credentials |

---

## 12. Implementation references

| Path | Role |
|------|------|
| `soviez-saas/supabase/migrations/083_private_registry_pull_foundation.sql` | Schema + RLS |
| `soviez-saas/src/lib/registry/service.ts` | Session + resolve logic |
| `soviez-saas/src/app/api/installer/registry/**` | HTTP routes |
| Local `soviez-registry-gateway/` (internal) | OCI streaming gateway (not published in `soviez-deploy`) |
| `soviez-deploy/src/registry/` | Client pull consumer |

Model: `docs/ai/PRIVATE_REGISTRY_AND_PULL_AUTHORIZATION_MODEL.md`

---

## 13. Phase 8 installer wiring

`soviez.sh --new` consumes registry APIs after slot reservation:

| Step | Route | Module |
|------|-------|--------|
| Resolve release | `POST /api/installer/registry/releases/resolve` | `src/api/registry_client.sh` |
| Verify manifest | local Ed25519 | `src/registry/manifest_verify.sh` |
| Create pull session | `POST /api/installer/registry/pull-sessions` | `src/api/registry_client.sh` |
| Pull image | OCI v2 via gateway | `src/registry/pull_client.sh` |
| Complete session | `POST .../pull-sessions/complete` | `src/api/registry_client.sh` |

Temp docker `--config` directory created per pull and deleted after (certified: `tests/integration/test_cleanup_boundaries.sh`).

Full protocol: `docs/dev/NEW_COMMAND_PROTOCOL.md`

---

## 14. Phase 10.5 — Stage tooling via private registry (additive)

Stage commercial hardening reuses Phase 7 digest-pinning for **Stage tooling** (not ERP image tags):

| Property | Value |
|----------|-------|
| Catalog table | `stage_tooling_artifacts` (migration `086`) |
| Packaging (10.5 choice) | `signed_package` |
| Pull model | Digest-pinned private artifact — same non-public discipline as ERP releases |
| Fixture digest (tests) | `sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` |
| Ticket binding | `tooling_artifact_id` + `tooling_digest` on `soviez.stage-operation.v1` tickets |
| Signing domain | Stage tickets use **`soviez.stage-operation.v1`** — **not** `soviez.registry-pull-ticket.v1` |
| Keys in artifact | Public Stage Operation keys only — never Hub org tokens, never Stage Operation private keys |

Installer runtime pull of Stage tooling is wired in **Phase 11** (`--stage` + helper). Protocol detail: `docs/dev/STAGE_TOOLING_ARTIFACT.md`, `docs/dev/STAGE_RUNTIME_PROTOCOL.md`.

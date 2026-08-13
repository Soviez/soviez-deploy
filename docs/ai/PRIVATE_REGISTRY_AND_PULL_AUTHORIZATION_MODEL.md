# Private Registry and Pull Authorization Model

**Status:** Implemented (Phase 7 foundation) — **PASS**  
**Repos:** `soviez-saas` (migration `083`, `/api/installer/registry/*`, `src/lib/registry/*`); `soviez-sh/services/registry-gateway/`  
**Does not wire the installer.** Running ERP never depends on registry or SaaS availability.

---

## Objective

Deliver a **sovereignty-first private image pull authorization model** for Soviez ERP:

1. **Digest-first release catalog** — immutable `sha256:…` manifest digests are authoritative; display tags are informational only.
2. **Commercial entitlement gate** — `private_image_pull` capability via Phase 4 resolver (`commercial_grants`); no blanket account access.
3. **Device Proof-of-Possession (PoP)** — all SaaS pull APIs require Phase 5 signed device requests.
4. **Short-lived pull sessions** — SaaS issues Ed25519 pull tickets; clients never receive Docker Hub credentials.
5. **Dedicated streaming gateway** — Node service at `services/registry-gateway` proxies OCI blobs from Docker Hub upstream storage.
6. **Offline signed bundle foundation** — verifiable release manifests and bundle metadata without live registry access.
7. **ERP runtime independence** — image pull is an optional install/update operation; activated ERP continues offline if SaaS or registry is unavailable.

---

## Non-goals (Phase 7)

| Item | Deferred to |
|------|-------------|
| Installer command wiring (`docker pull` orchestration) | Later installer phase |
| Live Docker Hub private-repo cutover / visibility change | Owner-approved cutover |
| Commercial product mapping for all pull operation types | Later phases |
| Full offline archive distribution pipeline | Phase 23 |
| Push, delete, catalog browse, tag listing | Never (gateway denies) |
| Blob proxy through Vercel/Next.js | Never (architecture decision) |
| `local_license_guard` changes | Out of scope |

---

## Sovereignty boundaries

| Boundary | Rule |
|----------|------|
| **Running ERP** | Never requires continuous registry or SaaS connectivity after activation. Pull auth is for install/update only. |
| **Business data** | No database, filestore, or accounting data transits pull APIs or gateway. |
| **Upstream credentials** | Docker Hub pull-only secrets exist **only** in gateway environment — never in SaaS responses, never on client disk permanently. |
| **Client credentials** | Opaque `client_token` + Ed25519 `pull_ticket` are short-lived (15 min TTL). Temporary `docker --config` directory; delete after pull. |
| **Digest authority** | Client must pull `@sha256:…`; local verify must match authorized digest. No `:latest` fallback. |
| **Capability** | `private_image_pull` requires explicit `commercial_grants`; seed mapping does not auto-grant. |
| **Device auth** | Device link alone grants nothing; pull requires device PoP **and** capability **and** approved release. |

---

## Architecture decision (binding)

```
┌─────────────┐     Device PoP      ┌──────────────────┐
│  Installer  │ ──────────────────► │  soviez-saas     │
│  (future)   │   resolve / session │  Next.js APIs    │
└──────┬──────┘                     │  (no blob proxy) │
       │                            └────────┬─────────┘
       │ pull_ticket + temp docker config    │ issues tickets
       │                                     │ stores sessions
       ▼                                     ▼
┌─────────────┐   verify ticket     ┌──────────────────┐
│ Docker      │ ◄────────────────── │ registry-gateway │
│ client      │   stream OCI v2     │ Node HTTP        │
└─────────────┘                     └────────┬─────────┘
                                           │ Hub creds (env)
                                           ▼
                                  ┌──────────────────┐
                                  │ Docker Hub       │
                                  │ (upstream store) │
                                  └──────────────────┘
```

**Why separate Node gateway (not Vercel/Next.js):**

- Multi-GB layer blobs require **streaming** with Range support — no whole-body buffering.
- Vercel serverless **body size limits**, **execution timeouts**, and **bandwidth economics** make it unsuitable for OCI blob proxy.
- Gateway verifies pull tickets **offline** (Ed25519 public keys in env) — no SaaS round-trip per blob request.
- Hub pull-only token stays in gateway secret store; clients never see it.

See `docs/evidence/phase-07-private-registry/VERCEL_SUITABILITY_REVIEW.md` and `ARCHITECTURE_DECISION.md`.

---

## Release catalog (digest-first)

Table: `registry_releases` (migration `083`).

- **Authoritative field:** `manifest_digest` (`sha256:[64 hex]`)
- **Display only:** `display_tag`, `release_version` (human-readable)
- **Resolvable statuses:** `approved`, `published`
- **Withdrawn/revoked:** denied at resolve time
- **Architecture binding:** per-row `architecture` (e.g. `linux/amd64`); client cannot substitute digests
- **Repository allowlist:** `soviez/soviez-erp` (constants)

Resolve API returns signed release manifest alongside digest metadata.

---

## Signed release manifests

**Domain:** `soviez.release-manifest.v1`  
**Type field:** `soviez.release-manifest.v1`

Signing payload: `"soviez.release-manifest.v1\n" + canonical_json(payload)`

Canonical JSON uses recursively sorted object keys (arrays preserve order).

Manifest binds: `release_id`, `product_code`, `release_version`, `channel`, `repository`, `digest`, `architecture`, platform metadata, `min_installer_version`, `issued_at`, optional `expires_at` / `withdrawn`.

**Rules:**

- Must not sign `:latest` or repository strings containing `:latest`
- Digest must match `^sha256:[a-f0-9]{64}$`
- Verifiable offline with published public keys (`SOVIEZ_RELEASE_MANIFEST_PUBLIC_KEYS_JSON`)

---

## Device PoP + capability `private_image_pull`

All registry SaaS APIs use `requireDeviceSignedRequest` (Phase 5/6 device gate):

| Requirement | Enforcement |
|-------------|-------------|
| Active device credential | Signature verification |
| Account binding | Derived from device row |
| Capability | `resolveCapabilityEntitlement(…, "private_image_pull")` |
| Operation type | Allowlist: `new_install`, `product_update`, `stage_create`, `migration_bootstrap`, `repair_recovery`, `test_foundation` |

Capability seed in migration `083` maps `private_image_pull` but **does not auto-grant**. Tests insert explicit `commercial_grants`.

---

## Pull-session lifecycle

```
pending → active → completed
                 ↘ expired
                 ↘ revoked
                 ↘ denied / failed
```

| Phase | Behavior |
|-------|----------|
| **Create** | Idempotent on `(account_id, idempotency_key)`; issues credentials; status `active` |
| **Use** | Docker client presents pull ticket to gateway; gateway builds in-memory digest graph |
| **Refresh** | Up to 5 refreshes; max session age 1 hour; re-checks capability and release status |
| **Complete** | Client acknowledges; clears token hashes; terminal |
| **Revoke** | Client or policy; clears token hashes; gateway tickets expire naturally |
| **Expire** | Credential TTL (15 min) or max lifetime exceeded |

Events append-only in `registry_pull_session_events` (immutable).

---

## Token scope (pull-only)

Pull ticket claims (`soviez.registry-pull-ticket.v1`):

| Claim | Purpose |
|-------|---------|
| `scope` | Always `"pull"` — gateway rejects other scopes |
| `repository` | Single OCI repo (allowlisted) |
| `digest` | Root manifest digest authorized |
| `session_id` | Correlates gateway in-memory graph |
| `account_id`, `device_id`, `operation_id` | Audit binding |
| `iat`, `exp` | Short TTL (default 900 s) |
| `jti` | Unique ticket ID (hashed in session row) |
| `signer_key_id` | Ed25519 key rotation |

**No push, no catalog, no tag list, no cross-repo access.**

Gateway additionally enforces blob graph: only manifest digest + config + layers from fetched manifest are authorized for blob GET.

---

## Refresh and revocation

| Mechanism | Effect |
|-----------|--------|
| **Credential TTL** | Ticket `exp`; gateway returns `PULL_SESSION_EXPIRED` |
| **Refresh API** | New ticket + client token; increments `refresh_count`; idempotent refresh keys |
| **Revoke API** | Session `revoked`; clears stored token hashes |
| **Complete API** | Session `completed`; credentials invalidated |
| **Release withdrawn/revoked** | Refresh and resolve denied |
| **Capability lost** | Refresh denied (`CAPABILITY_REQUIRED`) |
| **Max refresh (5)** | `REFRESH_LIMIT_EXCEEDED` |
| **Max lifetime (1 h)** | `MAX_SESSION_AGE_EXCEEDED` |

SaaS stores `active_ticket_jti_hash` — new ticket replaces previous jti on refresh (prior ticket becomes unbound from session tracking; still expires by `exp`).

---

## Docker client PoP limitations

After `docker login` with temporary credentials:

- Docker stores auth in the temp `--config` directory — **not** a permanent Hub org token.
- Docker client does **not** re-sign per-blob requests with device PoP; security relies on **short-lived Ed25519 pull ticket** bound to digest + repo.
- Installer contract: create temp config → login → pull `@digest` → verify local digest → logout → delete config directory.
- PoP applies to **SaaS API calls** (session create/refresh), not to each OCI byte range.

---

## Offline bundle

Format: `offline-image-bundle/v1`

Bundle manifest includes: product/release metadata, digest, architecture, archive checksum, relative path, embedded signed release manifest.

Verification (`verifyOfflineBundleManifest`):

- Release manifest signature valid
- Digest matches signed payload
- Archive SHA-256 matches (when bytes provided)
- Rejects bundles containing private key material

Does not require Docker Hub at verify time. Full distribution pipeline deferred to Phase 23.

---

## Threat model summary

| Threat | Mitigation |
|--------|------------|
| Hub token exfiltration to client | Hub creds gateway-only; SaaS never returns upstream secrets |
| Pull without entitlement | Capability resolver + device PoP |
| Pull wrong image / tag confusion | Digest-only authority; no `:latest` signing |
| Cross-customer blob access | Ticket binds account/device/session/repo/digest |
| Ticket replay beyond TTL | Short `exp`; jti tracking |
| Blob outside authorized graph | Gateway ingests manifest; blob allowlist per session |
| Push / catalog enumeration | Gateway denies write + catalog + tags |
| Manifest tampering | Signed release manifest domain separation |
| RLS bypass | Sessions/releases: authenticated read-only scoped; service_role writes |
| SaaS outage stops ERP | ERP runs offline; pull is optional connected op |
| Vercel blob proxy abuse | Architecture excludes Next.js blob streaming |

---

## Installer integration (deferred)

Phase 7 delivers **server-side foundation only**:

- APIs callable with device-signed test harness
- Digest verify command contract documented
- Temp docker config shell snippet in protocol doc
- No changes to `local_license_guard` or installer runtime

Future installer phase will orchestrate: resolve → session → temp config pull → local digest verify → complete/revoke.

---

## Running ERP independence

**Confirmed rule:** A production Soviez ERP instance that is already activated and licensed **does not** contact the private registry or SaaS pull APIs during normal operation. Registry unavailability affects only **new installs, updates, or recovery pulls** that the operator explicitly initiates.

Device revocation, session expiry, or SaaS downtime **do not** stop or degrade an running ERP workload.

---

## Related documents

| Document | Purpose |
|----------|---------|
| `docs/dev/PRIVATE_REGISTRY_PROTOCOL.md` | Schemas, APIs, denial codes, OCI matrix |
| `docs/dev/REGISTRY_GATEWAY.md` | Gateway deployment contract |
| `services/registry-gateway/README.md` | Operator runbook |
| `docs/evidence/phase-07-private-registry/FINAL_REPORT.md` | Phase gate evidence |

---

## Phase 8 — installer wiring (PARTIAL)

Phase 8 `--new` command wires the pull client into the new-instance orchestration:

| Step | Module | Notes |
|------|--------|-------|
| Resolve + verify | `src/api/registry_client.sh`, `src/registry/manifest_verify.sh` | Digest pinned before pull |
| Pull session | `src/api/registry_client.sh` | Device PoP + capability |
| OCI pull | `src/registry/pull_client.sh` | Temp docker config; deleted after |
| Complete | `src/api/registry_client.sh` | Session closed on success |

**Status:** Implemented and certified with mock SaaS/gateway in test mode. Live Hub cutover still deferred.

See `docs/ai/NEW_INSTANCE_CONNECTED_ACTIVATION_MODEL.md`, `docs/dev/NEW_COMMAND_PROTOCOL.md`.

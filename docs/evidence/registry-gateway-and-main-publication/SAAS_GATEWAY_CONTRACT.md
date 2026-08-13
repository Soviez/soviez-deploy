# SAAS_GATEWAY_CONTRACT — Control Plane ↔ Gateway

## Protocol

| Field | Value |
|-------|-------|
| Protocol version | `registry-pull/v1` |
| Ticket signing domain | `soviez.registry-pull-ticket.v1` |
| Ticket format | Custom Ed25519 (**not** JOSE JWT) |
| Token shape | `base64url(canonical_json).base64url(ed25519_sig)` |
| Signed payload prefix | `"soviez.registry-pull-ticket.v1\n" + canonical_json` |

## Time bounds (centralized in SaaS)

| Constant | Value | Source |
|----------|------:|--------|
| `PULL_CREDENTIAL_TTL_SECONDS` | **900** (15 min) | `soviez-saas/src/lib/registry/constants.ts` |
| `PULL_SESSION_MAX_LIFETIME_SECONDS` | **3600** (1 hr) | same |
| `PULL_SESSION_MAX_REFRESH_COUNT` | **5** | same |

## Repository allowlist

| Allowed repository | Product |
|--------------------|---------|
| `soviez/soviez-erp` | `soviez-erp` |

Gateway enforces the same binding via ticket claims (`repository` field).

## Scope

| Operation | Allowed |
|-----------|---------|
| `pull` | **YES** |
| `push` | **NO** |
| catalog / tags list | **NO** |

## SaaS responsibilities (issuer)

| Function | Location |
|----------|----------|
| Pull session lifecycle | `soviez-saas/src/lib/registry/service.ts` |
| Ticket issuance | `soviez-saas/src/lib/registry/ticket.ts` |
| Release resolution | `soviez-saas/src/lib/registry/release-manifest.ts` |
| API routes | `soviez-saas/src/app/api/installer/registry/**` |

SaaS **issues** tickets and sessions; gateway **streams** OCI. SaaS never proxies blobs.

## Gateway responsibilities (verifier + proxy)

| Function | Location |
|----------|----------|
| Offline ticket verify | `soviez-sh/services/registry-gateway/src/ticket.ts` |
| Docker Registry V2 subset | `src/server.ts`, `src/proxy.ts` |
| Upstream Hub auth | Server-side only (`SOVIEZ_UPSTREAM_REGISTRY_*`) |

## Client-facing registry endpoints (SaaS → installer)

| Env (SaaS) | Purpose |
|------------|---------|
| `SOVIEZ_REGISTRY_GATEWAY_URL` | Gateway base URL returned to installer |
| `SOVIEZ_REGISTRY_TICKET_PRIVATE_KEY` | Ticket signing (SaaS only) |
| `SOVIEZ_REGISTRY_TICKET_PUBLIC_KEY` | Published to gateway public key map |

## Docker client login mapping

| Docker field | Ticket field |
|--------------|--------------|
| Username | `session_id` |
| Password | pull ticket token |

Gateway `/auth/token` exchanges verified ticket for Docker bearer metadata without exposing upstream secrets.

## Installer integration

Installer artifact `0.24.5.3-registry-gateway` includes registry-pull protocol wiring in `dist/soviez.sh` (`protocol_version: registry-pull/v1`).

## Cross-repo compatibility

See `CROSS_REPO_COMPATIBILITY.md`. Live end-to-end requires staged SaaS + gateway deployment — **PENDING**.

# GATEWAY_ARCHITECTURE — Soviez Registry Gateway

## Purpose

Dedicated streaming OCI registry gateway for **private pull-only** access to `soviez/soviez-erp` images. Clients never receive upstream Docker Hub credentials.

## Canonical paths

| Role | Path |
|------|------|
| Local ops / installable package | `/Volumes/PortableSSD/soviez-project/soviez-registry-gateway` |
| soviez-sh mirror (publication staging) | `soviez-sh/services/registry-gateway/` |
| Published location | `services/registry-gateway/` in `Soviez/soviez-deploy` |

Sync rule: keep local ops folder and soviez-sh mirror **byte-identical** before publication.

## High-level flow

```
Installer / docker client
    │  Bearer pull ticket (Ed25519, offline-verifiable)
    ▼
registry.soviez.com (nginx TLS → gateway :8087)
    │  verify ticket, enforce repo+digest graph
    │  server-side Basic auth to upstream
    ▼
registry-1.docker.io (Docker Hub)
    │  manifest + blob stream
    ▼
Client (pull only)
```

## Components

| Layer | Implementation |
|-------|----------------|
| Edge TLS | `nginx/registry.soviez.com.conf` |
| HTTP server | Node ≥20, `src/server.ts` |
| Ticket verify | `src/ticket.ts` — Ed25519, domain `soviez.registry-pull-ticket.v1` |
| Auth / bindings | `src/auth.ts` — Bearer + Basic (docker login path) |
| Digest graph | `src/graph.ts` — session-scoped blob allowlist |
| Upstream proxy | `src/proxy.ts` — streaming, Range support |
| Denial | `src/denial.ts` — structured error codes |
| Log redaction | `src/redact.ts` — no credential egress in logs |
| Packaging | `install.sh`, `compose.yml`, `Dockerfile`, systemd unit |

## API surface (Docker Registry HTTP V2 subset)

| Method | Path | Behavior |
|--------|------|----------|
| GET | `/live`, `/ready`, `/health` | Health probes |
| GET | `/v2/` | 401 + `WWW-Authenticate` unless valid ticket |
| GET | `/auth/token` | Ticket → Docker bearer token exchange |
| GET/HEAD | `/v2/<repo>/manifests/<digest>` | Authorized manifest only |
| GET/HEAD | `/v2/<repo>/blobs/<digest>` | Authorized blob (graph-bound) |
| * | `/v2/_catalog`, `/tags/list`, PUT/DELETE/POST | **Denied** |

## Authorization model

1. Ticket binds `repository` + root manifest `digest` + session/account/device claims.
2. Manifest fetch builds in-memory digest graph keyed by `session_id`.
3. Blob pulls must match a digest in that graph.
4. Upstream Hub credentials used **only** on server-side proxy hop.

## Domains

| Environment | Host |
|-------------|------|
| Production | `registry.soviez.com` |
| Staging | `registry-staging.soviez.com` |

## Upstream

| Field | Value |
|-------|-------|
| Default host | `registry-1.docker.io` |
| Env | `SOVIEZ_UPSTREAM_REGISTRY_HOST` |
| Credentials | `SOVIEZ_UPSTREAM_REGISTRY_USER` / `SOVIEZ_UPSTREAM_REGISTRY_TOKEN` (gateway host only) |

## Package version

Service package: `@soviez/registry-gateway` **0.1.0** (`VERSION` file). Installer artifact version is separate: `0.24.5.3-registry-gateway`.

## References

- `soviez-sh/docs/dev/REGISTRY_GATEWAY_ARCHITECTURE.md`
- `soviez-sh/services/registry-gateway/README.md`
- `soviez-sh/services/registry-gateway/CANONICAL_SOURCE.md`

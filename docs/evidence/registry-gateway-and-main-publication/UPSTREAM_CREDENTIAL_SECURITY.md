# UPSTREAM_CREDENTIAL_SECURITY — Docker Hub Credentials

## Policy

Upstream Docker Hub pull credentials exist **only** on the registry gateway host. They are never returned to clients, never embedded in tickets, and never logged.

## Configuration

| Variable | Location | Exposure |
|----------|----------|----------|
| `SOVIEZ_UPSTREAM_REGISTRY_HOST` | Gateway env | Non-secret (default `registry-1.docker.io`) |
| `SOVIEZ_UPSTREAM_REGISTRY_USER` | Gateway env | **Secret — server only** |
| `SOVIEZ_UPSTREAM_REGISTRY_TOKEN` | Gateway env | **Secret — server only** |

Production path: `/etc/soviez-registry-gateway/gateway.env` (mode `640` or stricter).

## Upstream target

| Field | Value |
|-------|-------|
| Registry | Docker Hub |
| Host | `registry-1.docker.io` |
| Auth | HTTP Basic (Hub PAT) on server-side proxy hop only |

## Separation from client credentials

| Credential type | Held by | Used for |
|-----------------|---------|----------|
| Soviez pull ticket | Client / docker | Gateway authorization |
| Hub user/token | Gateway host only | Upstream manifest/blob fetch |

## Code enforcement

| Mechanism | File |
|-----------|------|
| Proxy injects upstream auth internally | `src/proxy.ts` |
| Token exchange never includes upstream fields | `src/server.ts` `/auth/token` |
| Log redaction strips upstream env patterns | `src/redact.ts` |
| Tests assert no upstream secret in responses | `test/gateway.test.ts` |

## Verification

| Check | Result |
|-------|--------|
| Token endpoint response excludes Hub token | **PASS** (unit test) |
| Token endpoint response excludes Hub user | **PASS** (`real-oci-pull-proof.sh`) |
| Logs exclude upstream secret | **PASS** (`LOG_REDACTION.md`) |

## Rotation procedure

Documented in `services/registry-gateway/docs/SECURITY.md`:

1. Rotate Hub PAT at Docker Hub.
2. Update `gateway.env` on gateway host.
3. Reload gateway (systemd/compose).
4. No client-side change required.

## Git / publication

Hub credentials **must not** appear in:

- Git history
- Example env files (placeholders only)
- Installer artifact `dist/soviez.sh`
- SaaS codebase

Status: **PASS** for this cycle (secret scan + static review).

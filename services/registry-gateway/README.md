# Soviez Registry Gateway

Dedicated streaming OCI registry gateway for private registry pulls.

**Package version:** `0.1.0` (see `VERSION`)  
**Canonical domains:** `registry.soviez.com` (production), `registry-staging.soviez.com` (staging)  
**Canonical source map:** [CANONICAL_SOURCE.md](CANONICAL_SOURCE.md)

## Purpose

- Speaks **Docker Registry HTTP API V2** for pull clients
- Verifies short-lived **Soviez pull tickets** (Ed25519, domain `soviez.registry-pull-ticket.v1`) offline
- Proxies **only** the authorized repository + digest graph to an upstream registry
- **Never** exposes upstream credentials to clients (Hub user/token stay on the gateway host only)
- Streams blobs without whole-layer buffering
- Supports **Range** requests with `Content-Length` / `Content-Range` preservation
- Denies push, delete, catalog, and tag listing

## Operator install (production)

Ubuntu-focused packaging lives in this tree:

```bash
sudo ./install.sh      # idempotent; snapshots + rollback on failure
sudo ./healthcheck.sh  # /live /ready /health
sudo ./update.sh
sudo ./uninstall.sh    # add --purge to remove config/state
```

Docs:

| Doc | Topic |
|-----|--------|
| [docs/INSTALLATION.md](docs/INSTALLATION.md) | Install, prerequisites, rollback |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | Env vars, domains, nginx |
| [docs/OPERATIONS.md](docs/OPERATIONS.md) | Health, logs, systemd/Compose |
| [docs/SECURITY.md](docs/SECURITY.md) | Credential boundary, hardening |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common failures |
| [docs/UPGRADE.md](docs/UPGRADE.md) | Updates |
| [docs/RECOVERY.md](docs/RECOVERY.md) | Restore from snapshot |

Compose: `docker compose up -d --build` (see `compose.yml` + `Dockerfile`). TLS: `nginx/registry.soviez.com.conf` (cert path placeholders).

## Deployment contract

### Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PORT` | No | `8087` | HTTP listen port |
| `SOVIEZ_REGISTRY_TICKET_PUBLIC_KEYS_JSON` | Yes (prod) | — | JSON map `{ "rtk_…": "<raw ed25519 pubkey base64url>" }` |
| `SOVIEZ_UPSTREAM_REGISTRY_HOST` | No | `registry-1.docker.io` | Upstream registry host (Docker Hub) |
| `SOVIEZ_UPSTREAM_REGISTRY_USER` | Prod | — | Upstream pull username (gateway secret) |
| `SOVIEZ_UPSTREAM_REGISTRY_TOKEN` | Prod | — | Upstream pull token (gateway secret) |
| `SOVIEZ_UPSTREAM_BASE_URL` | Tests/dev | — | Full upstream base URL override (e.g. mock) |

### Endpoints

| Method | Path | Behavior |
|--------|------|----------|
| `GET` | `/live` | Liveness |
| `GET` | `/ready` | Readiness |
| `GET` | `/health` | Alias for live/ready ok payload |
| `GET` | `/v2/` | `401` + `WWW-Authenticate` unless valid Bearer ticket |
| `GET` | `/auth/token` | Exchange verified pull ticket → Docker bearer token |
| `GET`/`HEAD` | `/v2/<repo>/manifests/<digest>` | Authorized manifest only |
| `GET`/`HEAD` | `/v2/<repo>/blobs/<digest>` | Authorized blob graph only |
| * | `/v2/_catalog`, `/tags/list`, write methods | Denied |

### Pull ticket format

Token = `base64url(canonical_json_claims).base64url(ed25519_sig)`

Signed payload: `"soviez.registry-pull-ticket.v1\n" + canonical_json`

Claims: `typ`, `jti`, `session_id`, `account_id`, `device_id`, `operation_id`, `repository`, `digest`, `architecture`, `scope` (`pull`), `iat`, `exp`, `signer_key_id`.

### Authorization model

1. Ticket binds `repository` + root manifest `digest`.
2. On manifest fetch, gateway builds an in-memory **digest graph** (config + layers) keyed by `session_id`.
3. Blob pulls must match a digest in that graph.
4. Upstream Hub credentials are used only on the server-side proxy hop.

### Local development

```bash
cp .env.example .env   # placeholders only — never commit real secrets
npm install
npm run typecheck
npm test
npm run build
npm start
```

Graceful shutdown on `SIGTERM` / `SIGINT`.

Keypair instructions (no secrets written into the tree): `./scripts/generate-keypair.sh`

## Security notes

- Upstream tokens are never logged (see `src/redact.ts`).
- No Supabase or SaaS business logic in this service.
- Push/delete/catalog are explicitly denied.
- Container image: non-root, no `docker.sock`, capabilities dropped.

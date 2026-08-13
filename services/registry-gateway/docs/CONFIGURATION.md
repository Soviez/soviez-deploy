# Configuration — Soviez Registry Gateway

## Domains

| Environment | Hostname |
|-------------|----------|
| Production | `registry.soviez.com` |
| Staging | `registry-staging.soviez.com` |

TLS terminates at nginx (or another reverse proxy). The Node process listens on loopback `:8087` by default (`compose.yml`).

## Environment variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PORT` | No | `8087` | HTTP listen port |
| `SOVIEZ_REGISTRY_TICKET_PUBLIC_KEYS_JSON` | Yes (prod) | — | JSON map `{ "rtk_…": "<raw ed25519 pubkey base64url>" }` |
| `SOVIEZ_UPSTREAM_REGISTRY_HOST` | No | `registry-1.docker.io` | Upstream registry host |
| `SOVIEZ_UPSTREAM_REGISTRY_USER` | Prod | — | Upstream pull username (**gateway host secret**) |
| `SOVIEZ_UPSTREAM_REGISTRY_TOKEN` | Prod | — | Upstream pull token (**gateway host secret**) |
| `SOVIEZ_UPSTREAM_BASE_URL` | Dev/test | — | Full upstream base URL override (mock) |

Files:

- Package example: `.env.example`
- Sample for install: `config/gateway.env.example`
- Live host path: `/etc/soviez-registry-gateway/gateway.env` (mode `640`)

## Credential boundary

- Hub username/token are used **only** on the server-side proxy hop to upstream.
- They must **never** appear in client responses, tickets, or logs (see `src/redact.ts`).
- Ticket signing **private** keys belong to the issuer/control plane, not typically on the gateway.
- Gateway holds **public** verification keys only (plus upstream pull secrets).

Generate keypair instructions (no secrets emitted into the tree):

```bash
./scripts/generate-keypair.sh
```

## nginx

Template: `nginx/registry.soviez.com.conf`

Replace:

- `CERT_FULLCHAIN_PATH`
- `CERT_PRIVKEY_PATH`

Then enable the site. Staging hostname is documented in comments (`registry-staging.soviez.com`).

## Compose bind

Default publish: `127.0.0.1:8087:8087`. Override with `SOVIEZ_RGW_BIND` / `PORT` if needed. Do not expose Hub credentials via Compose labels or public env endpoints.

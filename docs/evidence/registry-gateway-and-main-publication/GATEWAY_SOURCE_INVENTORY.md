# GATEWAY_SOURCE_INVENTORY — Soviez Registry Gateway

## Package metadata

| Field | Value |
|-------|-------|
| npm name | `@soviez/registry-gateway` |
| Package version | `0.1.0` |
| Node engine | `>=20` |
| Type | ESM (`"type": "module"`) |

## Application source (`src/`)

| File | Purpose |
|------|---------|
| `index.ts` | Entry bootstrap |
| `server.ts` | HTTP server, routing, lifecycle |
| `config.ts` | Env/config loading |
| `ticket.ts` | Ed25519 pull ticket issue/verify |
| `auth.ts` | Bearer/Basic parsing, claim bindings |
| `graph.ts` | Session digest graph for blob authorization |
| `proxy.ts` | Upstream streaming proxy (Range-aware) |
| `denial.ts` | Structured denial codes/responses |
| `redact.ts` | Secret redaction for logs |
| `mock-upstream.ts` | Test/disposable upstream mock |

## Tests

| File | Coverage |
|------|----------|
| `test/gateway.test.ts` | 20 unit/integration tests — **20/20 PASS** |

## Scripts

| File | Purpose |
|------|---------|
| `scripts/real-oci-pull-proof.sh` | REAL_PRIVATE_IMAGE_PULL end-to-end proof |
| `scripts/generate-keypair.sh` | Operator keypair generation (no secrets in tree) |
| `scripts/status.sh` | Runtime status helper |

## Operator packaging

| File | Purpose |
|------|---------|
| `install.sh` | Idempotent install + rollback |
| `uninstall.sh` | Remove (+ `--purge` option) |
| `update.sh` | In-place update |
| `healthcheck.sh` | `/live` `/ready` `/health` |
| `compose.yml` | Docker Compose deployment |
| `Dockerfile` | Container image (non-root) |
| `systemd/soviez-registry-gateway.service` | systemd unit |
| `nginx/registry.soviez.com.conf` | TLS edge config template |

## Configuration templates

| File | Purpose |
|------|---------|
| `.env.example` | Dev env placeholders |
| `config/gateway.env.example` | Production env template |
| `config/site.example.conf` | Site config template |

## Documentation

| File | Topic |
|------|-------|
| `README.md` | Overview + contract |
| `CANONICAL_SOURCE.md` | Publish path + sync rule |
| `docs/INSTALLATION.md` | Install procedure |
| `docs/CONFIGURATION.md` | Env vars |
| `docs/OPERATIONS.md` | Health, logs, systemd |
| `docs/SECURITY.md` | Trust model, secrets |
| `docs/TROUBLESHOOTING.md` | Common failures |
| `docs/UPGRADE.md` | Update path |
| `docs/RECOVERY.md` | Snapshot restore |

## Build artifacts (excluded from git)

| Path | Reason |
|------|--------|
| `dist/` | TypeScript compile output |
| `node_modules/` | npm dependencies |

## Publication tree

All paths above (excluding `node_modules/`, `dist/`, local `.env`) publish to:

`Soviez/soviez-deploy/services/registry-gateway/`

Local mirror roots (byte-synced):

- `/Volumes/PortableSSD/soviez-project/soviez-registry-gateway`
- `soviez-sh/services/registry-gateway/`

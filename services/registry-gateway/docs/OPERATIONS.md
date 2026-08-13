# Operations — Soviez Registry Gateway

## Service control

```bash
sudo systemctl status soviez-registry-gateway
sudo systemctl restart soviez-registry-gateway
sudo ./scripts/status.sh
```

Compose (from install root `/opt/soviez-registry-gateway`):

```bash
docker compose -f compose.yml ps
docker compose -f compose.yml logs -f --tail=200
```

## Health endpoints

| Path | Role |
|------|------|
| `GET /live` | Process liveness |
| `GET /ready` | Readiness |
| `GET /health` | Alias (same ok payload) |

Local probe:

```bash
./healthcheck.sh
# or
curl -fsS http://127.0.0.1:8087/live
curl -fsS https://registry.soviez.com/ready
```

Expected body: `{"status":"ok"}`.

## Registry API surface (ops view)

- `GET /v2/` — auth challenge / ticket bearer
- `GET /auth/token` — ticket → Docker bearer exchange
- Manifest/blob pull under `/v2/<repo>/…` when authorized
- Push, delete, catalog, tag list — denied

## Logging

- Container logs via Compose `json-file` (10m × 3)
- Do not enable debug dumps that print Authorization headers or Hub tokens
- `src/redact.ts` strips sensitive tokens from log helpers

## Capacity notes

- Blobs stream without whole-layer buffering
- Range requests supported with length/range headers preserved
- nginx should keep `proxy_buffering off` and large/zero `client_max_body_size` as in the template

## Graceful shutdown

Process handles `SIGTERM` / `SIGINT`. Compose/`docker stop` should drain within unit `TimeoutStopSec`.

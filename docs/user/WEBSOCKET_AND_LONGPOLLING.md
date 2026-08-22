# WebSocket and Longpolling

**Status:** CODE-SYNCHRONIZED (multi-worker corrective architecture)  
**Artifact:** `0.24.6.3-platform-cli`

## Canonical topology (SUPPORTED)

When automatic sizing selects multiprocessing (`workers > 0`):

```text
proxy_mode = True
list_db = False
workers = <calculated>
gevent_port = 8072

Client :443 / WSS
 → Nginx
   /            → 127.0.0.1:8069   (HTTP workers)
   /websocket   → 127.0.0.1:8072   (evented / gevent)
   /longpolling → 127.0.0.1:8072   (compatibility)
```

On very small hosts, sizing may select an explicit minimal fallback (`workers = 0`) with WebSocket on the HTTP backend.

Soviez automatically sizes runtime configuration from available server resources. Do not treat raw formulas as customer SLAs.

## Longpolling

**COMPATIBILITY_ROUTED** — routed to the evented backend when multi-worker topology is active.

## Production & Stage

Both require `proxy_mode = True` behind Nginx. Stage conf writer includes `proxy_mode = True`.

## Phase-12 SSL-owned Nginx

SSL lifecycle owned templates include `/websocket` + `/longpolling` + Upgrade headers (template `phase12-ws2`). Requires host `map $http_upgrade $connection_upgrade`.

## Ports

| Port | Exposure |
|------|----------|
| 443 | PUBLIC WSS edge |
| 8069 | LOOPBACK / NOT public (HTTP) |
| 8072 | LOOPBACK / NOT public (evented/WebSocket) |
| 8071 | NOT public |
| 5432 | NEVER public |

## Troubleshooting

| Symptom | Cause | Safe action |
|---------|-------|-------------|
| 404 `/websocket` | Old Nginx template | Re-render owned/S2 site; do not open 8069/8072 |
| 400/426 | Missing Upgrade map | Ensure `soviez_limits.conf` / S2 map |
| 502/504 | Upstream/host port wrong | Check loopback publish for 8069 and 8072 |
| Notifications missing | workers>0 without gevent_port | Run `soviez.sh --tune` |

Never expose 8069 or 8072 publicly.

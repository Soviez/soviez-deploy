# WebSocket and Longpolling

**Status:** CODE-SYNCHRONIZED (post-cert discrepancy closure)  
**Artifact:** `0.24.5.3-registry-gateway`

## Canonical certified topology (SUPPORTED_AND_CERTIFIED)

```text
workers = 0
proxy_mode = True
Client :443 / WSS
 → Nginx (/websocket, /longpolling compatibility)
 → 127.0.0.1:HOST_PORT
 → Odoo HTTP :8069
```

```text
workers > 0 = NOT_SUPPORTED
dedicated gevent_port publish = NOT_SUPPORTED
```

Resource tuning (`--formworkers`) may size memory/cgroups using a formula, but **Odoo workers remain 0**.

## Longpolling

**COMPATIBILITY_ROUTED** — same upstream as `/websocket` / HTTP (not a separate gevent port).

## Production & Stage

Both require `proxy_mode = True` behind Nginx. Stage conf writer includes `proxy_mode = True`.

## Phase-12 SSL-owned Nginx

SSL lifecycle owned templates include `/websocket` + `/longpolling` + Upgrade headers (template `phase12-ws1`). Requires host `map $http_upgrade $connection_upgrade` (ERP `soviez_limits` / S2).

## Ports

| Port | Exposure |
|------|----------|
| 443 | PUBLIC WSS edge |
| 8069 | LOOPBACK / NOT public |
| 8071/8072 | NOT published; public = FAIL |
| 5432 | NEVER public |

## Troubleshooting

| Symptom | Cause | Safe action |
|---------|-------|-------------|
| 404 `/websocket` | Old Nginx template | Re-render owned/S2/ERP site; do not open 8069 |
| 400/426 | Missing Upgrade map | Ensure `soviez_limits.conf` / S2 map |
| 502/504 | Upstream/host port wrong | Check `SOVIEZ_HOST_PORT` loopback publish |
| Notifications missing | workers>0 without gevent | Set workers=0 (certified) |
| Wrong gevent port | Expecting 8072 | Unsupported — use 8069 topology |

Never expose 8069/8072 publicly to "fix" WebSocket.

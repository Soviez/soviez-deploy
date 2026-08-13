# WebSocket / Longpolling Architecture

## Canonical rule (post-cert)

SUPPORTED_AND_CERTIFIED: `workers=0`, `proxy_mode=True`, Nginx `/websocket` (+ `/longpolling` compat) → host loopback → container **8069**.

NOT_SUPPORTED: `workers>0`, `gevent_port`, public 8071/8072.

Assert helper: `src/security/platform/websocket_topology.sh`.

## Templates

| Template | WS | Longpoll | Owner |
|----------|----|----------|-------|
| ERP `write_nginx_site` | yes | yes (compat) | dual wizard |
| S2 `nginx_edge.sh` | yes | yes | security platform |
| Phase-12 `ownership.sh` | yes (`phase12-ws1`) | yes | SSL lifecycle |
| P21 cutover nginx | yes | yes | migration |

## Evidence

`docs/evidence/post-cert-discrepancy-closure/`

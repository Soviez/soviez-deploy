# WEBSOCKET_LONGPOLLING_SOURCE_AUDIT

Derived from live sources (2026-08-12 documentation canonicalization).

| Source | Generated | Route | Port | Test/Evidence | Documented behavior |
|--------|-----------|-------|------|---------------|---------------------|
| Soviez ERP `write_nginx_site` | per-tenant nginx conf | `/`, `/websocket` | loopback HOST→8069 | ERP provision + S1 port isolation | Production SoT: WS to 8069; no `/longpolling` |
| ERP `ensure_nginx_global_limits` | `soviez_limits.conf` map Upgrade | http context | N/A | README formsetup | Required for WS upgrade |
| ERP `_docker_run_web` | `-p 127.0.0.1:HOST:8069` | publish | 8069 | `test_odoo_port_isolation` | LOOPBACK only |
| ERP `ensure_tenant_soviez_conf` | `proxy_mode=True`, workers=0 | N/A | 8069 | `test_odoo_prod_defaults` | proxy_mode mandatory |
| `src/security/platform/nginx_edge.sh` `soviez_nginx_s2_render_hardened` | S2 snippet | `/websocket`,`/longpolling`,`/` | same upstream→8069 | `test_nginx_hardening` | S2 SoT includes longpolling→same upstream |
| `src/nginx/ownership.sh` | Phase-12 SSL conf | `/` only | upstream arg | SSL paths | Lacks WS — AMBIGUOUS for realtime |
| `src/nginx/render.sh` | stub | `/` | caller | stub | Non-production |
| `odoo_exposure.sh` | asserts | watches 8069/8071/8072 | — | S1/S2 gates | Public publish FAIL |
| Gevent wiring | none set | — | 8072 unused | import smoke only | AMBIGUOUS if workers>0 |

**Public path:** Browser → :443 Nginx → 127.0.0.1:HOST → :8069.  
**Do not** expose 8069/8072 to fix WebSocket.

# WEBSOCKET_CONTRACT

Supported topology (D129):
- `workers = 0`
- `proxy_mode = True` (Production **and** Stage)
- `/websocket` → internal Odoo **8069**
- `/longpolling` → compatibility routed (same upstream)
- `workers > 0` / gevent: NOT_SUPPORTED

Verified in dual wizard (`ensure_stage_soviez_conf`, formworkers force `ODOO_WORKERS=0`, nginx routes).  
Modular: `src/nginx/ownership.sh`, migration nginx, `src/security/platform/websocket_topology.sh`.

Ports not public: 8069, 8071, 8072, 5432.

Result: **CONSISTENT across publishable runtime sources audited.**

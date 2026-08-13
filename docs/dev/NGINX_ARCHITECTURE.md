# Nginx Architecture

## Two production-relevant SoTs

1. **ERP wizard** `write_nginx_site`: `/` + `/websocket` → loopback→8069; no `/longpolling`
2. **S2 hardened** `soviez_nginx_s2_render_hardened`: `/websocket` + `/longpolling` → same upstream

Phase-12 `src/nginx/ownership.sh` SSL template historically lacks WS locations — prefer ERP or S2 for realtime.

Upgrade map: ERP `ensure_nginx_global_limits` → `soviez_limits.conf`.

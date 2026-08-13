# Nginx / edge security audit

Production: Nginx TLS + proxy to `127.0.0.1:HOST_PORT`.
Cloudflare: live IP list fetch (good); needs cached/offline refresh SoT — do not hardcode forever in source.

Gaps to design: HSTS, version leakage, request-size limits, rate limits, websocket timeouts, real_ip from CF, EDGE_MODE=direct|cloudflare|cloudflare_aop.

Direct upstream Odoo still publishable (C2) — edge alone insufficient.

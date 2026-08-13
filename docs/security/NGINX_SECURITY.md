# Nginx security (S2)

Owned Soviez templates set `server_tokens off`, TLS 1.2/1.3, proxy headers, Odoo-friendly timeouts/body size, websocket/longpolling locations, HTTP→HTTPS redirect, and targeted `/web/login` rate limits. CSP is Report-Only to avoid breaking Odoo assets. Virtualmin-owned vhosts are detected and not overwritten blindly.

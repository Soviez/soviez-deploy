# Edge / Cloudflare (S2)

`EDGE_MODE=direct|cloudflare|cloudflare_aop`. Cloudflare ranges come from last-known-good cache plus operator-initiated refresh (`SOVIEZ_CF_ALLOW_NETWORK_REFRESH=1`). Never replace with an empty allowlist. `cloudflare_aop` is unsupported unless explicitly enabled with a client CA.

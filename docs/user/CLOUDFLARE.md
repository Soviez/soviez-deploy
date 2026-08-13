# Cloudflare

Cloudflare is **optional**, not mandatory.

## Mode

`SOVIEZ_EDGE_MODE=direct` (default) or `cloudflare_aop`.

When using Cloudflare:

- Ensure origin certificates / Authenticated Origin Pulls match chosen mode
- DNS validation and TLS troubleshooting differ from direct mode
- Do not expose origin 8069 even behind Cloudflare

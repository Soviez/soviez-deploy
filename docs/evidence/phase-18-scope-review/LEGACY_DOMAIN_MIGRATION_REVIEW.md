# LEGACY_DOMAIN_MIGRATION_REVIEW.md

## Legacy (`soviez-deploy/soviez.sh`) behaviors

| Behavior | Description | Phase 18 stance |
|----------|-------------|-----------------|
| `--formssl` | Diagnose/repair HTTPS (LE or self-signed Cloudflare Full) | Do **not** accept self-signed as final; LE patterns inform ACME but via Phase 12 abstraction |
| `--change-domain` | Repoint tenant DNS/Nginx/HTTPS to new domain | **Unsafe default** — this is cutover-class mutation; belongs Phase 21, not 18 |
| Certbot nginx hooks | Host LE renewal | Reuse concept; local keys only |
| `safe_nginx_reload` | Isolate broken sites on `nginx -t` fail | Reuse carefully; **exact** site only — no broad cleanup |
| `stop_web_for_maintenance` / `run_odoo_maintenance*` | Stops ERP web for DB/maintenance containers | **Forbidden** in Phase 18 landing model |
| Port collision vs caddy/traefik | Detection only | Nginx remains mandatory initial proxy |

## Legacy “migrate”

Legacy “migrate” mostly means filesystem path migration (`/etc` drop-zone → `/soviez`), **not** Soviez-to-Soviez streaming. Do not confuse with Phase 19.

## SaaS

No dedicated SaaS DNS-challenge or DNS-provider credential API found for customer Production domains. Stage origin certificates are Stage-only. Migration token APIs exist for later burn (Phase 20) — **out of Phase 18**.

## Verdict

Legacy domain change is a **cautionary anti-pattern** for Phase 18. Phase 18 learns LE/nginx safety, rejects ERP-stop maintenance and Production-domain repoint as defaults.

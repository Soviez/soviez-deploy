# DOMAIN_SSL_MATRIX — Phase 8

**Modules:** `src/ssl/local_ca.sh`, `src/ssl/validate.sh`, `src/ssl/letsencrypt.sh`, `src/nginx/render.sh`

## Modes

| Mode | Trigger | Module | Certification |
|------|---------|--------|---------------|
| Local CA (dev/test) | `--domain` + test/provision | `ssl/local_ca.sh` | **PASS** — `test_ssl_local_ca.sh`, `test_domain_ssl.sh` |
| Let's Encrypt (prod) | `--domain` + production | `ssl/letsencrypt.sh` | Present; production cutover Phase 12 |
| No domain | Omit `--domain` | Skip SSL/nginx | PASS in tests without domain flag |

## State transitions (with domain)

```
container_started → domain_pending → waiting_for_dns → ssl_pending → instance_provisioned
```

In test mode, DNS wait is immediate stub transition.

## Local CA certification

`tests/integration/test_ssl_local_ca.sh`:
- Issues cert + key + CA
- Validates chain via `soviez_ssl_validate_chain`
- Confirms PEM structure

`tests/unit/test_domain_ssl.sh`:
- Domain validation helpers
- Config path conventions

## Nginx

`soviez_nginx_render_config "$domain" "$container:8069"` — reverse proxy template rendered to operation-scoped path.

## Production note

Self-signed / local CA suitable for certification only. Production Let's Encrypt policy (D010) remains owner decision for Phase 12.
